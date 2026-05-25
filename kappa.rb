require 'sinatra'
require 'csv'

set :bind, '0.0.0.0'
# 注文データを入れる箱（テーブル ＞ アバター ＞ 商品）
$orders = {}

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
# 1. トップページ（テーブル一覧）
# ---------------------------------------------------------
get '/' do
  @tables = (1..20).to_a
  erb :table
end

# ---------------------------------------------------------
# 2. アバター選択画面（指定したテーブル用）
# ---------------------------------------------------------
get '/table/:table_id' do
  @table_id = params[:table_id]
  @avatars = load_avatars
  erb :avatar_select
end

# ---------------------------------------------------------
# 3. 注文画面（指定テーブル ＞ 指定アバター）
# ---------------------------------------------------------
get '/table/:table_id/avatar/:avatar_id' do
  @table_id = params[:table_id]
  @avatar_id = params[:avatar_id]
  @avatars = load_avatars
  @products = load_products

  @av = @avatars[@avatar_id]
  if @av == nil
    return "<h1>エラー🍣</h1><a href='/table/#{@table_id}'>戻る</a>"
  end

  # 箱の準備
  $orders[@table_id] ||= {}
  $orders[@table_id][@avatar_id] ||= []

  # 個人の現在の合計
  @my_total = 0
  $orders[@table_id][@avatar_id].each { |pid| @my_total += @products[pid][:price] if @products[pid] }

  erb :order
end

# ---------------------------------------------------------
# 4. お会計まとめ画面（テーブル全体の確認）
# ---------------------------------------------------------
get '/table/:table_id/summary' do
  @table_id = params[:table_id]
  @avatars = load_avatars
  @products = load_products
  @table_orders = $orders[@table_id] || {}

  erb :summary
end

# ---------------------------------------------------------
# 5. 注文を受け取る処理
# ---------------------------------------------------------
post '/order' do
  tid = params[:table_id]
  aid = params[:avatar_id]
  pid = params[:product_id]

  $orders[tid] ||= {}
  $orders[tid][aid] ||= []
  $orders[tid][aid] << pid

  redirect "/table/#{tid}/avatar/#{aid}"
end

# ---------------------------------------------------------
# 6. お会計（リセット）処理
# ---------------------------------------------------------
post '/checkout' do
  tid = params[:table_id]
  
  # 指定されたテーブルの中身だけをリセット
  $orders[tid] = {}

  redirect '/'
end
