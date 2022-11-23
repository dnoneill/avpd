require 'test_helper'
require 'json'
class AvconverterJobTest < ActiveJob::TestCase
  include AvHelper
  test 'that audio can be converted' do

    args = {:inputpath=>"/vagrant/test/fixtures/files/4507-16021-0012/4507-16021-0012.wav", :outputpath => '/vagrant/test/fixtures/files/output'}
    avmaterial = Avmaterial.find_or_create_by(slug: File.basename(args[:inputpath], ".*"))
    avtype = ENV['audiofiletypes'].split(",").include?(File.extname(args[:inputpath]).delete('.').downcase) ? "audio" : "video"
    avmaterial.avtype = avtype
    avmaterial.inputpath = args[:inputpath]
    avmaterial.converted = 'loaded'
    avmaterial.save
    AvconverterJob.perform_now(args)
    updatedavmaterial = Avmaterial.find_by(inputpath: args[:inputpath])
    assert_equal updatedavmaterial.issilent, false
    assert_equal updatedavmaterial.converted, "true"
    assert_nil updatedavmaterial.processerror
    assert_equal updatedavmaterial.avtype, "audio"
    assert_equal JSON.parse(updatedavmaterial.ffmpeginfo)['metadata']['format']['duration'], "2.808000"
    assert_equal JSON.parse(updatedavmaterial.silencedata).length, 1  
    assert_equal updatedavmaterial.duration, "2.808000"
    assert_equal updatedavmaterial.waveform, {"id"=>"http://localhost:3333/4507-16021-0012/4507-16021-0012.json", "format"=>"application/json", "label"=>"Waveform JSON"}
    assert_equal updatedavmaterial.poster, {"id"=>"https://cdn.pixabay.com/photo/2017/07/09/20/48/speaker-2488096_1280.png", "format"=>"image/png", "width"=>1280, "height"=>1280, "label"=>"Poster image"}
    assert_equal updatedavmaterial.avmaterial, [{"id"=>"http://localhost:3333/4507-16021-0012/4507-16021-0012.mp3", "format"=>"audio/mp3"}, {"id"=>"http://localhost:3333/4507-16021-0012/4507-16021-0012.ogg", "format"=>"audio/ogg"}]
    assert_equal updatedavmaterial.captions, {"id"=>"http://localhost:3333/4507-16021-0012/4507-16021-0012.vtt", "format"=>"text/vtt", "label"=>"Captions"}
    assert_equal getTranscript(updatedavmaterial), "Why should one halt on the way?"
    assert_nil updatedavmaterial.sprites
    assert_nil updatedavmaterial.transcript
  end

  test 'that audio with pdf' do

    args = {:inputpath=>"/vagrant/test/fixtures/files/8455-210777-0068/8455-210777-0068.wav", :outputpath => '/vagrant/test/fixtures/files/output'}
    begin
      FileUtils.mkdir('/vagrant/test/fixtures/files/output/8455-210777-0068')
    rescue
    end
    FileUtils.cp('/vagrant/test/fixtures/files/8455-210777-0068.pdf', '/vagrant/test/fixtures/files/output/8455-210777-0068')
    avmaterial = Avmaterial.find_or_create_by(slug: File.basename(args[:inputpath], ".*"))
    avtype = ENV['audiofiletypes'].split(",").include?(File.extname(args[:inputpath]).delete('.').downcase) ? "audio" : "video"
    avmaterial.avtype = avtype
    avmaterial.inputpath = args[:inputpath]
    avmaterial.converted = 'loaded'
    avmaterial.save
    AvconverterJob.perform_now(args)
    updatedavmaterial = Avmaterial.find_by(inputpath: args[:inputpath])
    assert_equal updatedavmaterial.issilent, false
    assert_equal updatedavmaterial.converted, "true"
    assert_nil updatedavmaterial.processerror
    assert_equal updatedavmaterial.avtype, "audio"
    assert_equal JSON.parse(updatedavmaterial.ffmpeginfo)['metadata']['format']['duration'], "2.664000"
    assert_equal JSON.parse(updatedavmaterial.silencedata).length, 2
    assert_equal updatedavmaterial.duration, "2.664000"
    assert_equal updatedavmaterial.poster, {"id"=>"https://cdn.pixabay.com/photo/2017/07/09/20/48/speaker-2488096_1280.png", "format"=>"image/png", "width"=>1280, "height"=>1280, "label"=>"Poster image"}
    assert_equal updatedavmaterial.avmaterial, [{"id"=>"http://localhost:3333/8455-210777-0068/8455-210777-0068.mp3", "format"=>"audio/mp3"}, {"id"=>"http://localhost:3333/8455-210777-0068/8455-210777-0068.ogg", "format"=>"audio/ogg"}]
    assert_equal updatedavmaterial.waveform, {"id"=>"http://localhost:3333/8455-210777-0068/8455-210777-0068.json", "format"=>"application/json", "label"=>"Waveform JSON"}
    assert_nil updatedavmaterial.captions
    assert_nil updatedavmaterial.sprites
    assert_equal getTranscript(updatedavmaterial), ""
    assert_equal updatedavmaterial.transcript, [{"id"=>"http://localhost:3333/8455-210777-0068/8455-210777-0068.pdf", "format"=>"application/pdf", "label" => "PDF transcript"}]
  end
  
end
