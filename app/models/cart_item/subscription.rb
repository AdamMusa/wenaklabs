# frozen_string_literal: true

# A subscription added to the shopping cart
class CartItem::Subscription < CartItem::BaseItem
  def initialize(plan)
    raise TypeError unless plan.class == Plan

    @plan = plan
  end

  def price
    amount = @plan.amount
    elements = { plan: amount }

    { elements: elements, amount: amount }
  end
end
