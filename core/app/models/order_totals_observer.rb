# Observe models that need to affect the total fields on Order
class OrderTotalsObserver < ActiveRecord::Observer
  observe :line_item, :adjustment, :payment

  def after_save(object)
    object.order.update_totals! if object.order
  end

  def after_destroy(object)
    object.order.update_totals! if object.order
  end

end
