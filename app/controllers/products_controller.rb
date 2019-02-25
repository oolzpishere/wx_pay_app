class ProductsController < ApplicationController
  protect_from_forgery except: :notify
  before_action :support_wx_pay?
  before_action :invoke_wx_auth
  before_action :get_wechat_sns

  before_action :set_product, only: [:show, :edit, :update, :destroy, :invoke]

  # GET /products
  # GET /products.json
  def index
    @products = Product.all
  end

  # GET /products/1
  # GET /products/1.json
  def show

  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
  end

  # POST /products
  # POST /products.json
  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to @product, notice: 'Product was successfully created.' }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1
  # PATCH/PUT /products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to @product, notice: 'Product was successfully updated.' }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1
  # DELETE /products/1.json
  def destroy
    @product.destroy
    respond_to do |format|
      format.html { redirect_to products_url, notice: 'Product was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def invoke
    params = {
      body: @product.name,
      out_trade_no: out_trade_no,
      total_fee: @product.price,
      spbill_create_ip: '127.0.0.1',
      notify_url: 'http://test_pay.sflx.com.cn/notify',
      # trade_type: 'NATIVE', # could be "MWEB", ""JSAPI", "NATIVE" or "APP",
      openid: session[:openid] # required when trade_type is `JSAPI`
    }
    if support_wx_pay?
      params[:trade_type] = 'JSAPI'
      # params[:openid] =
    else
      params[:trade_type] = 'NATIVE'
    end

    @r = WxPay::Service.invoke_unifiedorder params
    p @r


    if 1 || params[:trade_type] == 'JSAPI'
      jsapi_params = {
        prepayid: @r['prepay_id'],
        noncestr: SecureRandom.uuid.tr('-', '')
      }
      @r = WxPay::Service.generate_js_pay_req jsapi_params
      # byebug
      p @r
    end

    respond_to do |format|
      # format.html { redirect_to products_url, notice: 'Product was successfully destroyed.' }
      format.json { render json: @r, status: :ok }
    end
  end

  def notify

    result = Hash.from_xml(request.body.read)["xml"]

    if WxPay::Sign.verify?(result)
      puts '#'*55
      puts result

      render :xml => {return_code: "SUCCESS"}.to_xml(root: 'xml', dasherize: false)
    else
      render :xml => {return_code: "FAIL", return_msg: "签名失败"}.to_xml(root: 'xml', dasherize: false)
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def product_params
      params.fetch(:product, {}).permit(:name, :price, :position)
    end

    def out_trade_no
      time_now_string = Time.now.to_i.to_s
      # 12 digits random num
      out_trade_no_rand = (0..11).map {rand(9)}.join
      time_now_string + out_trade_no_rand
    end

    def user_agent
      request.headers['User-Agent']
    end

    def user_agent_hash
      scan_arrays = user_agent.scan(/\w+\/[\d\.]+/)
      # getting:
      # ["Mozilla/5.0", "AppleWebKit/537.36", "Chrome/72.0.3626.109", "Safari/537.36"]

      buf = {}
      scan_arrays.map do |string|
        k, v = string.split('/')
        v = v.to_f
        buf[k] = v if v > 0
      end

      buf
    end

    def support_wx_pay?
      user_agent_hash['MicroMessenger'] && user_agent_hash['MicroMessenger'] >= 5.0
    end

    def invoke_wx_auth
      if params[:state].present? || session['openid'].present?
        return
      end

      sns_url = WxPay::Service.generate_authorize_url(request.url.sub(/https/, 'http'))
      redirect_to sns_url and return
    end

    # 在invoke_wx_auth中做了跳转之后，此方法截取
    def get_wechat_sns
      # params[:state] 这个参数是微信特定参数，所以可以以此来判断授权成功后微信回调。
      if session[:openid].blank? && params[:state].present?
        sns_info = WxPay::Service.authenticate(params[:code])
        Rails.logger.debug("Weixin oauth2 response: #{sns_info}")
        # 重复使用相同一个code调用时：
        if sns_info["errcode"] != "40029"
          session[:openid] = sns_info["openid"]
          puts session[:openid]
        end
      end
    end
end
