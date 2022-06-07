require 'test_helper'

class ApiControllerTest < ActionDispatch::IntegrationTest
  test "send api failure" do
    post api_convert_url, params: { avfilepath: '/fixtures/files/failure_response' }
    assert_response 400
  end
  
  test "send api success" do
    post api_convert_url, params: { avfilepath:  file_fixture('8455-210777-0068')}
    @avitem = Avmaterial.find_by(slug: '8455-210777-0068')
    assert_equal @avitem.converted, 'inqueue'
    assert_equal @avitem.avtype, 'audio'
    assert_equal @avitem.publiccaps, false
    assert_response 200
  end

  test "search api" do
    get api_search_url, params: { q:  ''}
    assert_equal JSON.parse(@response.body).map{|elem| elem['slug']}, ["ua024-002-bx0113-213-001","efgh", "abcd" ]
    assert_equal JSON.parse(@response.body).length, 3
  end

  test "search api with parameters 'caption'" do
    get api_search_url, params: { q:  'caption'}
    assert_equal JSON.parse(@response.body).map{|elem| elem['slug']}, ["abcd","efgh"]
    assert_equal JSON.parse(@response.body).length, 2
  end

  test "search api with parameters 'test caption'" do
    get api_search_url, params: { q:  'test caption'}
    assert_equal JSON.parse(@response.body).map{|elem| elem['slug']}, ["efgh","abcd"]
    assert_equal JSON.parse(@response.body).length, 2
  end

  test "video api result" do
    get av_api_url('ua024-002-bx0113-213-001')
    assert_equal JSON.parse(@response.body), {"context"=>"http://localhost:3333/api/context", "slug"=>"ua024-002-bx0113-213-001", "id"=>"http://localhost:3333/api/av/ua024-002-bx0113-213-001", "type"=>"https://schema.org/VideoObject", "embedurl"=>"http://localhost:3333/embed/ua024-002-bx0113-213-001", "poster"=>{"id"=>ENV['default_poster'], "format"=>"image/png", "width"=>1280, "height"=>1280, "label"=>"Poster image"}, "avmaterial"=>nil, "captions"=>{"id"=>"http://localhost:3333/vagrant/test/fixtures/files/captions/ua024-002-bx0113-213-001/ua024-002-bx0113-213-001.vtt", "format"=>"text/vtt", "label"=>"Captions"}, "sprites"=>nil, "transcript"=>[{"id"=>"http://localhost:3333/transcript/ua024-002-bx0113-213-001", "format"=>"text/txt", "label"=>"Text transcript"}], "issilent"=>false, "duration"=>nil, "waveform"=>nil}
  end
end
