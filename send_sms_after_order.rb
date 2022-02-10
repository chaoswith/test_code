  def send_sms_purchase_info(order)
    phone = order.purchase_info_phone

    unless phone
      if params[:imp_uid]
        Iamport.configure do |config|
          config.api_key = Constants.import[:key]
          config.api_secret = Constants.import[:secret]
        end
        http_party = Iamport.payment(params[:imp_uid])
        result = JSON.parse http_party.body
        response = result['response']
        phone = response['buyer_tel']
      end
    end

    if Rails.env == 'production' || Rails.env == 'staging'
      product_info = "[#{Constants.site_name}]\n"
      product_info+="주문번호 #{order.order_number}\n\n"
      order.order_products.each do |order_product|
        product_info+="#{order_product.product.title} / #{order_product.select_option_names_without_amount} / #{order_product.amount}\n"
      end
      product_info+="주문 완료되었습니다:)\n\n▶ [#{Constants.site_name}] 바로가기\n#{Constants.sms_url_mobile}"
      
      body = JSON.dump({
                                   "msg_type" => "AL",
                                   "mt_failover" => "Y",
                                   "msg_data" => {
                                       "senderid" => "#{Constants.sms_from}",
                                       "to" => "82#{phone[1..-1]}",
                                       "content" => product_info
                                   },
                                   "msg_attr" => {
                                       "sender_key" => "#{Constants.sms_sender_key}",
                                       "template_code" => "#{Constants.sms_template_code}",
                                       "response_method" => "push",
                                       "attachment" => {
                                           "button" => [
                                               {
                                                   "name"=> "구매내역 확인하기",
                                                   "type"=> "WL",
                                                   "url_mobile"=> "#{Constants.sms_url_mobile}",
                                                   "url_pc"=> ""
                                               }
                                           ]
                                       }
                                   }
                               })
    
      SendKakaotalkController.perform_async(body,nil)
      
    else
      #비회원
      if order.user.email.include?('@guest.com')
        message = "[#{Constants.site_name}]
상품 주문 완료되셨습니다
주문번호 : #{order.order_number.to_s}"
        result = %x[curl 'https://rest.supersms.co/sms/xml' -d id=#{Constants.sms_id} -d pwd=#{Constants.sms_password} -d from=#{Constants.sms_from} -d to_country=82 -d to=#{phone[1..-1]} --data-urlencode 'message=#{message}' -d report_req=1]
      else
        message = "[#{Constants.site_name}]
상품 주문 완료되셨습니다
주문배송확인 : http://bit.ly/2C7uE3o"
        result = %x[curl 'https://rest.supersms.co/sms/xml' -d id=#{Constants.sms_id} -d pwd=#{Constants.sms_password} -d from=#{Constants.sms_from} -d to_country=82 -d to=#{phone[1..-1]} --data-urlencode 'message=#{message}' -d report_req=1]
      end
      logger.info result.to_s
    end
  end