# frozen_string_literal: true

# This class provides helper methods to deal with coupons
class CouponService
  ##
  # Apply the provided coupon, if active, to the given price. Usability tests will be run depending on the
  # provided parameters.
  # If no coupon/coupon code or if the code does not match, return origin price without change
  #
  # @param total {Number} invoice total, before any coupon is applied
  # @param coupon {String|Coupon} Coupon's code OR Coupon object
  # @param user_id {Number} user's id against the coupon will be tested for usability
  # @return {Number}
  ##
  def apply(total, coupon, user_id = nil)
    price = total

    coupon_object = nil
    if coupon.instance_of? Coupon
      coupon_object = coupon
    elsif coupon.instance_of? String
      coupon_object = Coupon.find_by(code: coupon)
    end

    unless coupon_object.nil?
      if coupon_object.status(user_id, total) == 'active'
        if coupon_object.type == 'percent_off'
          price -= price * coupon_object.percent_off / 100.00
        elsif coupon_object.type == 'amount_off'
          # do not apply cash coupon unless it has a lower amount that the total price
          price -= coupon_object.amount_off if coupon_object.amount_off <= price
        end
      end
    end

    price
  end

  ##
  # Ventilate the discount of the provided coupon over the given amount proportionately to the invoice's total
  # @param total {Number} total amount of the invoice expressed in monetary units
  # @param amount {Number} price of the invoice's sub-item expressed in monetary units
  # @param coupon {Coupon} coupon applied to the invoice, amount_off expressed in centimes if applicable
  ##
  def ventilate(total, amount, coupon)
    price = amount
    if !coupon.nil? && total != 0
      if coupon.type == 'percent_off'
        price = amount - (amount * coupon.percent_off / 100.00)
      elsif coupon.type == 'amount_off'
        ratio = (coupon.amount_off / 100.00) / total
        discount = amount * ratio.abs
        price = amount - discount
      else
        raise InvalidCouponError
      end
    end
    price
  end

  ##
  # Compute the total amount of the given invoice, without the applied coupon
  # Invoice.total stores the amount payed by the customer, coupon deducted
  # @param invoice {Invoice} invoice object, its total before discount will be computed
  ##
  def invoice_total_no_coupon(invoice)
    total = (invoice.invoice_items.map(&:amount).map(&:to_i).reduce(:+) or 0)
    total / 100.0
  end
end
