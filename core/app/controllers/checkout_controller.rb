# Handles checkout logic.  This is somewhat contrary to standard REST convention since there is not actually a
# Checkout object.  There's enough distinct logic specific to checkout which has nothing to do with updating an
# order that this approach is waranted.
class CheckoutController < Spree::BaseController

  before_filter :load_order
  after_filter :cleanup_session

  # Updates the order and advances to the next state (when possible.)
  #
  # If the order is complete then user will be redirected to the :show view for the order.
  def update
    if @order.update_attributes(object_params)
      @order.update_attribute("state", params[:state])
      if @order.can_next?
        @order.next!
        redirect_to checkout_state_path(@order.state) and return
      end
    end
    render :edit
  end

  private

  def object_params
    # For payment step, filter order parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
    if @order.payment?
      if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]
        params[:order][:payments_attributes].first[:source_attributes] = source_params
      end
      if (params[:order][:payments_attributes])
        params[:order][:payments_attributes].first[:amount] = @order.total
      end
    end
    params[:order]
  end

  def load_order
    @order = current_order
    @order.state = params[:state] if params[:state]
    state_callback(:before)
    redirect_to order_path(@order) if @order.complete?
    redirect_to cart_path if @order.empty?
  end

  def cleanup_session
    session[:order_id] = nil if @order.complete?
  end

  def state_callback(before_or_after = :before)
    method_name = :"#{before_or_after}_#{@order.state}"
    send(method_name) if respond_to?(method_name, true)
  end

  def before_payment
    current_order.payments.destroy_all if request.put?
  end

  def before_address
    @order.bill_address ||= Address.new(:country => default_country)
    @order.ship_address ||= Address.new(:country => default_country)
  end

  # before_filter :load_data
  # before_filter :set_state
  # before_filter :enforce_registration, :except => :register
  # before_filter :ensure_order_assigned_to_user, :except => :register
  # before_filter :ensure_payment_methods
  # helper :users

  #resource_controller :singleton
  #actions :show, :edit, :update
  #belongs_to :order

  #ssl_required :update, :edit, :register

  # GET /checkout is invalid but we'll assume a bookmark or user error and just redirect to edit (assuming checkout is still in progress)
  # show.wants.html { redirect_to edit_object_url }
  #
  # edit.before :edit_hooks
  # delivery.edit_hook :load_available_methods
  # address.edit_hook :set_ip_address
  # payment.edit_hook :load_available_payment_methods
  # update.before :clear_payments_if_in_payment_state
  #
  # # customized verison of the standard r_c update method (since we need to handle gateway errors, etc)
  # def update
  #   load_object
  #
  #   # call the edit hooks for the current step in case we experience validation failure and need to edit again
  #   edit_hooks
  #   @checkout.enable_validation_group(@checkout.state.to_sym)
  #   @prev_state = @checkout.state
  #
  #   before :update
  #
  #   begin
  #     if @checkout.update_attributes object_params
  #       update_hooks
  #       @checkout.order.update_totals!
  #       after :update
  #       next_step
  #       if @checkout.completed_at
  #         return complete_checkout
  #       end
  #     else
  #       after :update_fails
  #       set_flash :update_fails
  #     end
  #   rescue Spree::GatewayError => ge
  #     logger.debug("#{ge}:\n#{ge.backtrace.join("\n")}")
  #     flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
  #   end
  #
  #   render 'edit'
  # end
  #
  # def register
  #   load_object
  #   @user = User.new
  #   if request.method == "POST"
  #     @checkout.email = params[:checkout][:email]
  #     @checkout.enable_validation_group(:register)
  #     if @checkout.email.present? and @checkout.save
  #       redirect_to edit_object_url
  #     end
  #     @checkout.errors.add t(:email) unless @checkout.email.present?
  #   end
  # end
  #
  # private
  #
  # def object_params
  #   # For payment step, filter checkout parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
  #   if object.payment?
  #     if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:checkout][:payments_attributes].first[:payment_method_id].underscore]
  #       params[:checkout][:payments_attributes].first[:source_attributes] = source_params
  #     end
  #     if (params[:checkout][:payments_attributes])
  #       params[:checkout][:payments_attributes].first[:amount] = @order.total
  #     end
  #   end
  #   params[:checkout]
  # end
  #
  # def complete_checkout
  #   complete_order
  #   order_params = {:checkout_complete => true}
  #   session[:order_id] = nil
  #   flash[:commerce_tracking] = I18n.t("notice_messages.track_me_in_GA")
  #   redirect_to order_url(@order, {:checkout_complete => true, :order_token => @order.token})
  # end
  #
  # def load_data
  #   @countries = Checkout.countries.sort
  #   # Retrieve bill address country and states
  #   default_country = get_default_country(:bill_address)
  #   @bill_states = default_country.states.sort
  #   # Retrieve bill address country and states
  #   default_country = get_default_country(:ship_address)
  #   @ship_states = default_country.states.sort
  #
  #   # prevent editing of a complete checkout
  #   redirect_to order_url(parent_object) if parent_object.checkout_complete
  # end
  #
  # def load_available_methods
  #   @available_methods = rate_hash
  #   @checkout.shipping_method_id ||= @available_methods.first[:id] unless @available_methods.empty?
  # end
  #
  # def clear_payments_if_in_payment_state
  #   if @checkout.payment?
  #     @checkout.payments.clear
  #   end
  # end
  #
  # def load_available_payment_methods
  #   @payment_methods = PaymentMethod.available(:front_end)
  #   if @checkout.payment and @checkout.payment.payment_method
  #     @payment_method = @checkout.payment.payment_method
  #   else
  #     @payment_method = @payment_methods.first
  #   end
  # end
  #
  # def set_ip_address
  #   @checkout.update_attribute(:ip_address, request.env['REMOTE_ADDR'])
  # end
  #
  # def complete_order
  #   if @checkout.order.out_of_stock_items.empty?
  #     flash.notice = t('order_processed_successfully')
  #   else
  #     flash.notice = t('order_processed_but_following_items_are_out_of_stock')
  #     flash.notice += '<ul>'
  #     @checkout.order.out_of_stock_items.each do |item|
  #       flash.notice += '<li>' + t(:count_of_reduced_by,
  #                             :name => item[:line_item].variant.name,
  #                             :count => item[:count]) +
  #                         '</li>'
  #     end
  #     flash.notice += '<ul>'
  #   end
  # end
  #
  # def rate_hash
  #   @checkout.shipping_methods(:front_end).collect do |ship_method|
  #     @checkout.shipment.shipping_method = ship_method
  #     { :id => ship_method.id,
  #       :name => ship_method.name,
  #       :cost => ship_method.calculate_cost(@checkout.shipment)
  #     }
  #   end.sort_by{|r| r[:cost]}
  # end
  #
  # def enforce_registration
  #   return if current_user or Spree::Config[:allow_anonymous_checkout]
  #   return if Spree::Config[:allow_guest_checkout] and object.email.present?
  #   store_location
  #   redirect_to register_order_checkout_url(parent_object)
  # end
  #
  # def accurate_title
  #   I18n.t(:checkout)
  # end
  #
  # def ensure_payment_methods
  #   if PaymentMethod.available(:front_end).none?
  #     flash[:error] = t(:no_payment_methods_available)
  #     redirect_to edit_order_path(params[:order_id])
  #     false
  #   end
  # end
  #
  # # Make sure that the order is assigned to the current user if logged in
  # def ensure_order_assigned_to_user
  #   load_object
  #   if current_user and @order.user != current_user
  #     @order.update_attribute(:user, current_user)
  #   end
  # end
  #

  # TODO - restore some of this default country logic eventually
  def default_country
    Country.find Spree::Config[:default_country_id]
  end

  # Determine the country for the specified +address type+,
  #
  # +address_type+ is either :bill_address or :shipping_address
  # def get_default_country(address_type)
  #   if object.send(address_type) && object.send(address_type).country
  #     default_country = object.send(address_type).country
  #   elsif current_user && current_user.send(address_type)
  #     default_country = current_user.send(address_type).country
  #   else
  #     default_country = Country.find Spree::Config[:default_country_id]
  #   end
  #   default_country
  # end

end
