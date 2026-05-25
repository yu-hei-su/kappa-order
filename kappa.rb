require 'sinatra'
require 'csv'

set :bind, '0.0.0.0'
$orders = {}

# ---------------------------------------------------------
# 1. データの準備（CSV読み込み）
# ---------------------------------------------------------
helpers do
  def load_avatars
    avatars = {}
    CSV.foreach('avatars.csv', headers: true) do |r|
      avatars[r['id']] = { name: r['name'], icon: r['icon'] }
    end
    avatars
  end

  def load_products
    products = {}
    CSV.foreach('products.csv', headers: true) do |r|
      products[r['id']] = { name: r['name'], price: r['price'].to_i, image: r['image'] }
    end
    products
  end
end

# ---------------------------------------------------------
# 2. トップページ
# ---------------------------------------------------------

get '/' do
  @qr_url = "#{request.base_url}/group/kappa_table"
  erb :kappa 
end
# ---------------------------------------------------------
# 3. URL解析と画面表示
# ---------------------------------------------------------
get '/group/*' do
  path = request.path_info
  parts = path.split('/') 
  
  @group_id  = parts[2]
  sub_mode   = parts[3] # "avatar" か "summary" か
  @avatar_id = parts[4] # "1" など

  @avatars = load_avatars
  @products = load_products

  # --- A. お会計まとめ画面 ---
  if sub_mode == "summary"
    @table_orders = $orders[@group_id] || {}
    erb :summary

  # --- B. 注文画面 ---
  elsif sub_mode == "avatar" && @avatar_id != nil && @avatar_id != ""
    @av = @avatars[@avatar_id]

    if @av == nil
      return "<h1>エラー：アバターが見つかりません🍣</h1><p>URLが間違っている可能性があります。</p><a href='/group/#{@group_id}'>テーブルに戻る</a>"
    end

    $orders[@group_id] ||= {}
    $orders[@group_id][@avatar_id] ||= []

    @my_total = 0
    $orders[@group_id][@avatar_id].each { |pid| @my_total += @products[pid][:price] }

    erb :order

  # --- C. アバター選択画面 ---
  else
    erb :avatar_select
  end
end

# ---------------------------------------------------------
# 4. 注文を受け取る処理
# ---------------------------------------------------------
post '/order' do
  request.body.rewind 
  raw_body = request.body.read
  
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

# ---------------------------------------------------------
# 5. お会計（リセット）処理
# ---------------------------------------------------------
post '/checkout' do
 
  request.body.rewind 
  raw_body = request.body.read
  
  my_data = {}
  pairs = raw_body.split('&') 
  pairs.each do |pair|
    key_value = pair.split('=')
    my_data[key_value[0]] = key_value[1]
  end

  gid = my_data["group_id"]

 
  $orders[gid] = {}

  redirect '/'
end
