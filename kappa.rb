require 'sinatra'
require 'sinatra/reloader'
require 'csv'

set :bind, '0.0.0.0'
$orders = {}

# ---------------------------------------------------------
# 1. データの準備（CSV読み込み）
# ---------------------------------------------------------
helpers do
  def load_avatars
    avatars = {}
    CSV.foreach('avatars.csv', headers: true) { |r| avatars[r['id']] = { name: r['name'], icon: r['icon'] } }
    avatars
  end

   def load_products
    products = {}
    CSV.foreach('products.csv', headers: true) do |r|
      # 【修正】最後に image: r['image'] を追加しました
      products[r['id']] = { name: r['name'], price: r['price'].to_i, image: r['image'] }
    end
    products
  end

end

# ---------------------------------------------------------
# 2. トップページ
# ---------------------------------------------------------
get '/' do
  qr_url = "#{request.base_url}/group/kappa_table"
  "<h1>QR</h1><img src='https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=#{qr_url}'><br><a href='/group/kappa_table'>PC用</a>"
end
# ---------------------------------------------------------
# 3. URL解析と画面表示
# ---------------------------------------------------------
get '/group/*' do
  path = request.path_info
  parts = path.split('/') 
  
  # 【修正1】曖昧に探すのをやめ、配列の「番目」をカッチリ指定して取り出す！
  group_id  = parts[2]
  sub_mode  = parts[3] # "avatar" か "summary" か
  avatar_id = parts[4] # "1" など

  avatars = load_avatars
  products = load_products

  # --- A. お会計まとめ画面 ---
  if sub_mode == "summary"
    table_orders = $orders[group_id] || {}
    html = "<h1>お会計まとめ</h1><ul>"
    grand_total = 0
    avatars.each do |id, av|
      items = table_orders[id] || []
      sum = 0
      items.each { |pid| sum += products[pid][:price] }
      grand_total += sum
      html += "<li>#{av[:icon]} #{av[:name]}: #{sum}円</li>"
    end
    html += "</ul><h2>合計: #{grand_total}円</h2><a href='javascript:history.back();'>戻る</a>"
    return html

  # --- B. 注文画面 ---
  elsif sub_mode == "avatar" && avatar_id != nil && avatar_id != ""
    av = avatars[avatar_id]

    # 【修正2】もし変なURLでアクセスされて、アバターが nil だった場合の逃げ道を作る！
    if av == nil
      return "<h1>エラー：アバターが見つかりません🍣</h1><p>URLが間違っている可能性があります。</p><a href='/group/#{group_id}'>テーブルに戻る</a>"
    end

    $orders[group_id] ||= {}
    $orders[group_id][avatar_id] ||= []

    my_total = 0
    $orders[group_id][avatar_id].each { |pid| my_total += products[pid][:price] }

    html = "<h1>#{av[:icon]} #{av[:name]}さんの注文</h1>"
    html += "<h3>現在の合計: #{my_total}円</h3><hr>"
    
    html += "<form action='/order' method='POST'>"
    html += "<input type='hidden' name='group_id' value='#{group_id}'>"
    html += "<input type='hidden' name='avatar_id' value='#{avatar_id}'>"
       # --- 商品をタイル状に並べるためのコンテナ ---
    html += "<div style='display: flex; flex-wrap: wrap; gap: 15px; margin-bottom: 20px;'>"
    
    products.each do |id, p|
      # それぞれの商品の「枠」を作る
      html += "<label style='border: 2px solid #ddd; border-radius: 8px; padding: 10px; text-align: center; cursor: pointer; width: 130px; background-color: #fff;'>"
      
      # ① 画像を表示（<img src=...> を使用）
      html += "<img src='#{p[:image]}' width='110' height='110' style='border-radius: 5px; display: block; margin: 0 auto 10px;'><br>"
      
      # ② ラジオボタンと文字
      html += "<input type='radio' name='product_id' value='#{id}' required> "
      html += "<strong>#{p[:name]}</strong><br><span style='color: #c0392b;'>#{p[:price]}円</span>"
      
      html += "</label>"
    end
    
    html += "</div>"

    html += "<button type='submit'>注文する！</button></form><hr>"
    html += "<a href='/group/#{group_id}/summary'>まとめを見る</a>"
    return html

  # --- C. アバター選択画面 ---
  else
    html = "<h1>アバターを選択</h1>"
    avatars.each do |id, data|
      html += "<p><a href='/group/#{group_id}/avatar/#{id}'>#{data[:icon]} #{data[:name]}</a></p>"
    end
    return html
  end
end
# ---------------------------------------------------------
# 4. 注文を受け取る処理（基礎技術・修正版）
# ---------------------------------------------------------
post '/order' do
  # 【超重要】Sinatraが裏で一度読んでしまっているので、テープを「巻き戻す」！
  request.body.rewind 
  
  # 巻き戻してから、生のテキストデータを読み込む
  raw_body = request.body.read
  
  # デバッグ用：ターミナルにどんな文字が届いたか表示してみましょう
  puts "★届いた生のデータ: #{raw_body}"
  
  # ----------------------------------------
  # ここから下は先ほどと全く同じです
  # ----------------------------------------
  my_data = {}
  pairs = raw_body.split('&') 
  
  pairs.each do |pair|
    key_value = pair.split('=')
    key = key_value[0]
    value = key_value[1]
    my_data[key] = value
  end

  gid = my_data["group_id"]
  aid = my_data["avatar_id"]
  pid = my_data["product_id"]

  $orders[gid] ||= {}
  $orders[gid][aid] ||= []
  $orders[gid][aid] << pid

  redirect "/group/#{gid}/avatar/#{aid}"
end
