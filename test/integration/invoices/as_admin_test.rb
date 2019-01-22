# frozen_string_literal: true

class InvoicesTest < ActionDispatch::IntegrationTest

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @admin = User.find_by(username: 'admin')
    login_as(@admin, scope: :user)
  end

  test 'admin list invoices' do
    post '/api/invoices/list', { query: {
      number: '',
      customer: '',
      date: nil,
      order_by: '-reference',
      page: 1,
      size: 20 # test db may have < 20 invoices
    } }.to_json, default_headers

    # Check response format & status
    assert_equal 200, response.status, response.body
    assert_equal Mime::JSON, response.content_type

    # Check that we have all invoices
    invoices = json_response(response.body)
    assert_equal Invoice.count, invoices.size, 'some invoices are missing'

    # Check that invoices are ordered by reference
    assert_equal '1604002', invoices.first[:reference]
    assert_equal '1203001', invoices.last[:reference]
  end

  test 'admin generates a refund' do
    date = DateTime.now.iso8601

    post '/api/invoices', { avoir: {
      avoir_date: date,
      avoir_mode: 'cash',
      description: 'Lorem ipsum',
      invoice_id: 4,
      invoice_items_ids: [4],
      subscription_to_expire: false
    } }.to_json, default_headers

    # Check response format & status
    assert_equal 201, response.status, response.body
    assert_equal Mime::JSON, response.content_type

    # Check that the refund match
    refund = json_response(response.body)
    avoir = Avoir.find(refund[:id])

    assert_dates_equal date, refund[:avoir_date]
    assert_dates_equal date, refund[:date]
    assert_equal 'cash', refund[:avoir_mode]
    assert_equal false, refund[:has_avoir]
    assert_equal 4, refund[:invoice_id]
    assert_equal 4, refund[:items][0][:invoice_item_id]
    assert_match %r{^[0-9]+/A$}, refund[:reference]
    assert_equal 'Lorem ipsum', avoir.description
  end

end
