class AvailabilitiesTest < ActionDispatch::IntegrationTest
  setup do
    admin = User.with_role(:admin).first
    login_as(admin, scope: :user)
  end

  test 'return availability by id' do
    a = Availability.take

    get "/api/availabilities/#{a.id}"

    # Check response format & status
    assert_equal 200, response.status
    assert_equal Mime::JSON, response.content_type

    # Check the correct availability was returned
    availability = json_response(response.body)
    assert_equal a.id, availability[:id], 'availability id does not match'
  end

  test 'get machine availabilities' do
    m = Machine.find_by_slug('decoupeuse-vinyle')

    get "/api/availabilities/machines/#{m.id}"

    # Check response format & status
    assert_equal 200, response.status
    assert_equal Mime::JSON, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    assert_not_nil availabilities[0], 'first availability was unexpectedly nil'
    assert_not_nil availabilities[0][:machine], "first availability's machine was unexpectedly nil"
    assert_equal m.id, availabilities[0][:machine][:id], "first availability's machine does not match the required machine"
  end
end
