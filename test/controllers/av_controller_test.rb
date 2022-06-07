require 'test_helper'

class AvControllerTest < ActionDispatch::IntegrationTest
  test "test index" do
    get av_index_url
    @av = assigns(:avmaterials)
    assert_equal "index", @controller.action_name
    assert_response :success
    assert_equal @av.length, 5
  end
  test "test index with parameters" do
    get av_index_url(avtype: 'video')
    @av = assigns(:avmaterials)
    assert_equal "index", @controller.action_name
    assert_response :success
    assert_equal @av[0].slug, 'efgh'
    assert_equal @av.length, 4
  end

  test "test with no results" do
    get av_index_url(avtype: 'videos')
    @av = assigns(:avmaterials)
    assert_equal "index", @controller.action_name
    assert_response :success
    assert_equal @av.length, 0
  end

  test "test embed page" do
    get embed_url(slug: 'test')
    assert_includes @response.body, '<av-viewer avapi="/api/av/test" startTime="" endTime="" time=""></av-viewer>'
  end
end
