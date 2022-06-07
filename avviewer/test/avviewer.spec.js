import Vue from 'vue'
import VModal from 'vue-js-modal'

//import index from 'karma-chai'
import { mount } from '@vue/test-utils';
import { createLocalVue } from '@vue/test-utils';

import avviewer from '../src/components/avviewer.vue';
import ResizeObserver from './__mocks__/ResizeObserver';

import flushPromises from 'flush-promises';
// let consoleSpy;
const localVue = createLocalVue();
const mockMethod = jest.fn()

localVue.use(VModal)

describe('Component', () => {
    beforeAll(() => {
      Object.defineProperty(HTMLElement.prototype, 'offsetHeight', { configurable: true, value: 500 })
      Object.defineProperty(HTMLElement.prototype, 'offsetWidth', { configurable: true, value: 500 })
    })
    test('test video without captions', async ()  => {
      const div = document.createElement('div')
      document.body.appendChild(div)
      const wrapper =  mount(avviewer,{
        localVue,
        propsData: {
          avapi: 'api1.json'
        },
        attachTo: div
      })
      wrapper.vm.addSeekButtons = mockMethod;
      await wrapper.vm.$nextTick()
      await flushPromises()
      var data = wrapper.vm.$data;
      expect(data.apidata).toEqual({"slug":"NCSU_vs_UNC_football_part4_1978","id":"http://localhost:3333/api/av/NCSU_vs_UNC_football_part4_1978","embedurl":"http://localhost:3333/embed/NCSU_vs_UNC_football_part4_1978","poster":{"id":"http://localhost:3333/processedav/NCSU_vs_UNC_football_part4_1978/NCSU_vs_UNC_football_part4_1978.png","format":"image/png","width":640,"height":480,"label":"Poster image"},"avmaterial":[{"id":"http://localhost:3333/processedav/NCSU_vs_UNC_football_part4_1978/NCSU_vs_UNC_football_part4_1978.webm","format":"video/webm","height":480,"width":640},{"id":"http://localhost:3333/processedav/NCSU_vs_UNC_football_part4_1978/NCSU_vs_UNC_football_part4_1978.mp4","format":"video/mp4","height":480,"width":640}],"captions":null,"type":"https://schema.org/VideoObject","sprites":{"id":"http://localhost:3333/processedav/NCSU_vs_UNC_football_part4_1978/NCSU_vs_UNC_football_part4_1978-sprite.vtt","format":"text/vtt","kind":"metadata","label":"image sprite metadata"},"transcript":null,"issilent":false,"duration":null})
      expect(wrapper.vm.downloadAVLink).toEqual({"format": "mp4", "link": "http://localhost:3333/processedav/NCSU_vs_UNC_football_part4_1978/NCSU_vs_UNC_football_part4_1978.mp4"});
      expect(wrapper.vm.embedUrl).toBe("http://localhost:3333/embed/NCSU_vs_UNC_football_part4_1978");
      expect(wrapper.vm.embedCode).toEqual('<iframe src="http://localhost:3333/embed/NCSU_vs_UNC_football_part4_1978"></iframe>');
      expect(data.captions).toEqual({})
      expect(data.searchshown).toEqual(false)
      expect(data.searchterm).toEqual('')
      expect(data.index).toEqual('')
      wrapper.destroy()
    })

    test('test audio with captions', async () => {
      const div = document.createElement('div');
      document.body.appendChild(div)
      const wrapper =  await mount(avviewer,{
        localVue,
        propsData: {
          avapi: 'api2.json'
        },
        attachTo: div
      })
      //wrapper.vm.getCaptionData();
      wrapper.vm.addSeekButtons = mockMethod;
      await wrapper.vm.$nextTick();
      await flushPromises();
      
      var data = wrapper.vm.$data;
      expect(data.apidata).toEqual({"slug":"mc00196-matsumoto-george-01-early-life","id":"http://localhost:3333/api/av/mc00196-matsumoto-george-01-early-life","embedurl":"http://localhost:3333/embed/mc00196-matsumoto-george-01-early-life","poster":{"id":"https://brand.ncsu.edu/img/downloads/hunt-interior-thumb.jpg","format":"image/png","width":750,"height":422,"label":"Poster image"},"avmaterial":[{"id":"http://localhost:3333/processedav/mc00196-matsumoto-george-01-early-life/mc00196-matsumoto-george-01-early-life.mp3","format":"audio/mp3"},{"id":"http://localhost:3333/processedav/mc00196-matsumoto-george-01-early-life/mc00196-matsumoto-george-01-early-life.ogg","format":"audio/ogg"}],"captions":{"id":"http://localhost:3333/processedav/mc00196-matsumoto-george-01-early-life/mc00196-matsumoto-george-01-early-life.vtt","format":"text/vtt","label":"Captions"},"type":"https://schema.org/audioObject","sprites":null,"transcript":[{"id":"http://localhost:3333/transcript/mc00196-matsumoto-george-01-early-life","format":"text/txt","label":"Text transcript"},{"id":"https://d.lib.ncsu.edu/pdfs/mc00196-matsumoto-george-01-early-life.pdf","format":"application/pdf","label":"PDF transcript"}],"issilent":false,"duration":null});
      await wrapper.vm.$nextTick();
      await flushPromises();
      expect(data.captions.cues[0]).toEqual({"identifier":"","start":0,"end":5,"text":"Caption \n00:00:05.001 --> 00:00:10.000\nCaption number 160,0,160,88","styles":"","startTime":"00:00:00.000","endTime":"00:00:05.000"})
      expect(data.captions.cues.length).toEqual(15)
      expect(data.searchresults.length).toBe(15)
      expect(data.searchshown).toBe(false)
      expect(data.searchterm).toEqual('')
      wrapper.setData({searchterm: 'testing'});
      expect(data.searchterm).toEqual('testing')
      wrapper.vm.updateSearch();
      expect(data.searchresults.length).toBe(1)
    
      expect(data.searchresults).toEqual([{"text": "No Results"}])
      expect(wrapper.vm.downloadAVLink).toEqual({"format": "mp3", "link": "http://localhost:3333/processedav/mc00196-matsumoto-george-01-early-life/mc00196-matsumoto-george-01-early-life.mp3"});
      expect(wrapper.vm.embedUrl).toBe("http://localhost:3333/embed/mc00196-matsumoto-george-01-early-life");
      expect(wrapper.vm.embedCode).toEqual('<iframe src="http://localhost:3333/embed/mc00196-matsumoto-george-01-early-life"></iframe>');

      wrapper.setData({searchterm: '160,264,160,88'});
      wrapper.vm.updateSearch();
      expect(data.searchresults.length).toBe(1)
      expect(data.searchresults).toEqual([{"identifier":"","start":65.001,"end":70,"text":"Caption number 160,264,160,88","styles":"","startTime":"00:01:05.001","endTime":"00:01:10.000"}])    
      wrapper.destroy()
    })

    test('test video in editor mode', async () => {
      const span = document.createElement('span')
      document.body.appendChild(span)
      const wrapper =  await mount(avviewer,{
        localVue,
        propsData: {
          avapi: 'api2.json',
          type: 'editor'
        },
        attachTo: span
      })
      wrapper.vm.addSeekButtons = mockMethod;
      await wrapper.vm.$nextTick();
      await flushPromises();
    
      var data = wrapper.vm.$data
      expect(data.apidata).toEqual({"slug":"mc00196-matsumoto-george-01-early-life","id":"http://localhost:3333/api/av/mc00196-matsumoto-george-01-early-life","embedurl":"http://localhost:3333/embed/mc00196-matsumoto-george-01-early-life","poster":{"id":"https://brand.ncsu.edu/img/downloads/hunt-interior-thumb.jpg","format":"image/png","width":750,"height":422,"label":"Poster image"},"avmaterial":[{"id":"http://localhost:3333/processedav/mc00196-matsumoto-george-01-early-life/mc00196-matsumoto-george-01-early-life.mp3","format":"audio/mp3"},{"id":"http://localhost:3333/processedav/mc00196-matsumoto-george-01-early-life/mc00196-matsumoto-george-01-early-life.ogg","format":"audio/ogg"}],"captions":{"id":"http://localhost:3333/processedav/mc00196-matsumoto-george-01-early-life/mc00196-matsumoto-george-01-early-life.vtt","format":"text/vtt","label":"Captions"},"type":"https://schema.org/audioObject","sprites":null,"transcript":[{"id":"http://localhost:3333/transcript/mc00196-matsumoto-george-01-early-life","format":"text/txt","label":"Text transcript"},{"id":"https://d.lib.ncsu.edu/pdfs/mc00196-matsumoto-george-01-early-life.pdf","format":"application/pdf","label":"PDF transcript"}],"issilent":false,"duration":null});
      await wrapper.vm.$nextTick();
      await flushPromises();
      expect(data.captions.cues[0]).toEqual({"identifier":"","start":0,"end":5,"text":"Caption \n00:00:05.001 --> 00:00:10.000\nCaption number 160,0,160,88","styles":"","startTime":"00:00:00.000","endTime":"00:00:05.000"})
      expect(data.captions.cues.length).toEqual(15)
      expect(data.searchresults.length).toBe(15)
      expect(data.searchshown).toBe(false)
      expect(data.searchterm).toEqual('')
      var text = wrapper.findAll('.editorline > textarea').at(0);
      text.element.value += ' update textarea'
      text.trigger('input')
      
      expect(text.element.value).toEqual('Caption \n00:00:05.001 --> 00:00:10.000\nCaption number 160,0,160,88 update textarea')
      expect(data.captions.cues[0].text).toEqual('Caption \n00:00:05.001 --> 00:00:10.000\nCaption number 160,0,160,88 update textarea');

      expect(wrapper.vm.createVTTFile()).toEqual("WEBVTT\n\n00:00:00.000 --> 00:00:05.000\nCaption \n00:00:05.001 --> 00:00:10.000\nCaption number 160,0,160,88 update textarea\n\n00:00:10.001 --> 00:00:15.000\nCaption number 320,0,160,88\n\n00:00:15.001 --> 00:00:20.000\nCaption number 480,0,160,88\n\n00:00:20.001 --> 00:00:25.000\nCaption number 0,88,160,88\n\n00:00:25.001 --> 00:00:30.000\nCaption number 160,88,160,88\n\n00:00:30.001 --> 00:00:35.000\nCaption number 320,88,160,88\n\n00:00:35.001 --> 00:00:40.000\nCaption number 480,88,160,88\n\n00:00:40.001 --> 00:00:45.000\nCaption number 0,176,160,88\n\n00:00:45.001 --> 00:00:50.000\nCaption number 160,176,160,88\n\n00:00:50.001 --> 00:00:55.000\nCaption number 320,176,160,88\n\n00:00:55.001 --> 00:01:00.000\nCaption number 480,176,160,88\n\n00:01:00.001 --> 00:01:05.000\nCaption number 0,264,160,88\n\n00:01:05.001 --> 00:01:10.000\nCaption number 160,264,160,88\n\n00:01:10.001 --> 00:01:15.000\nCaption number 320,264,160,88\n\n00:01:15.001 --> 00:01:20.000\nCaption number 480,264,160,88\n")
      wrapper.destroy()
    })
})
