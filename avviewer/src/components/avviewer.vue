<template>
<div v-if="apidata.id" class="videoplayer" v-bind:class="{editorplayer : type == 'editor'}">
  <div v-if="type == 'editor'" id="editorcontainer" class="editor">
    <div class="downloadbuttons">
      <input v-model="editor" placeholder="Caption editors">
      <button v-on:click="writeToApi()" v-if="writeapi" id="apisave">Save</button>
      <button v-on:click="downloadVTT()" class="downloadbuttons" id="download">Download</button>
      <input id="pauseontyping" type="checkbox" v-model="pauseontyping"/>
      <label for="pauseontyping">Pause video while typing</label>
    </div>
    <div id="editorcontent">
      <div v-for="(caption, index) in captions.cues" v-bind:key="index" class="editorline" v-bind:class="{active : caption.end >= playerCurrentTime && playerCurrentTime >= caption.start}">
        <div class="timecodes">
          <input v-on:keyup="updateTime(caption, 'start', index)" v-model="caption.startTime"><br>
          <input v-on:keyup="updateTime(caption, 'end', index)" v-model="caption.endTime">
        </div>
        <textarea v-on:keyup="updateCaptions(index)" v-on:focus="goToTime(caption.start)" v-on:keydown="pausePlayer();" v-model="caption.text"/>
        <div class="captionbuttons">
          <button v-on:click="addCaption(index)" v-bind:class="{ disabled: captions.cues[index+1] && (caption.end == captions.cues[index+1].start  || captions.cues[index+1].start-caption.end < 1) }">
            <i class="fa fa-plus-circle"></i>
          </button>
          <button v-on:click="deleteCaption(index)">
            <i class="fas fa-trash"></i>
          </button>
        </div>
      </div>
    </div>
  </div>
  <div class="videocontainer" v-bind:class="{editview : type == 'editor'}">
    <modal name="share" v-if="showEmbedCode || apidata.embedurl">
      <i class="fas fa-times closemodal" v-on:click="$modal.hide('share')"></i>
      <div style="padding: 40px" class="shareItems">
        <button v-on:click="switchEmbed()">
          <span v-if="!showEmbedCode">Embed <i class="fas fa-code"></i></span>
          <span v-else>Link <i class="fas fa-link"></i></span>
        </button>
        <div v-if="showEmbedCode" class="embed">
          <textarea id="embedCode" v-bind:value="embedCode" type="text" readonly/>
          <button v-on:click="copyEmbedUrl('embedCode')" id="copyButton">COPY</button>
        </div>
        <div class="embed" v-else-if="apidata.embedurl">
          <input v-bind:value="embedUrl" id="embedUrl" type="text" readonly>
          <button v-on:click="copyEmbedUrl('embedUrl')" id="copyButton">COPY</button>
        </div>
        <div>
          <input v-model="shareparams['time']['checked']" type="checkbox"/>Start at: <input v-model="shareparams['time']['value']"/>
        </div>
        <div>
          <h3>Share clip</h3>
          <input v-model="shareparams['starttime']['checked']" type="checkbox"/>Start clip at: <input v-model="shareparams['starttime']['value']"/><br>
          <input v-model="shareparams['endtime']['checked']" type="checkbox"/>End clip at: <input v-model="shareparams['endtime']['value']"/>
        </div>
      </div>
    </modal>
    <div id="searchcontainer" v-bind:class="[searchshown && captions.cues.length > 0 ? 'visiblesearch' : '']">
      <span v-if="searchshown && captions.cues.length > 0">
        <div class="stickyitem">
          <div style="position: relative">
            <button v-on:click="searchshown = !searchshown" class="closebutton captionbutton" aria-label="close search interface"><i class="fas fa-times"></i></button>
            <form @submit.prevent="updateSearch()">
              <input v-model="searchterm" class="searchterminput" v-focus type="search">
              <button type="submit" class="submitbutton">Submit</button> 
            </form>
          </div>
        </div>
        <div id="captionlist">
          <button v-for="(item, index) in searchresults" v-bind:key="index" v-on:click="skipTo(item)" class="captionbutton" v-bind:class="[index == currentcapindex ? 'activecaption' : '']">
            <span class="resultstime" v-if="item.startTime && item.endTime">{{item.startTime}}-<br>{{item.endTime}}</span>
            <span class="resultstext">{{item.text}}</span>
          </button>
        </div>
      </span>
    </div>
    <video controls v-bind:poster="apidata.poster ? apidata.poster['id'] : ''" v-bind:id="mediaid" class="video-js">
      <track type="caption" v-if="apidata.captions && !issrt" v-bind:key="apidata.captions['id']" :src="apidata.captions['id']" mode="showing" language="en" label="English">
    </video>
  </div>
  <div class="downloadlinks" v-if="type != 'editor'">
    <a class="btn btn-default" v-bind:href="downloadAVLink['link']" target="_blank"><span class="mobilehide">Download </span>{{downloadAVLink['format'].toUpperCase()}} <i class="fa fa-download"></i></a>
    <a class="btn btn-default" v-for="item in apidata.transcript" v-bind:key="item.id" v-bind:href="item.id" target="_blank"><span class="mobilehide">Download </span>{{item.label}} <i class="fa fa-download"></i></a>
    <a class="btn btn-default" v-on:click="openShareModal()"  v-if="showEmbedCode || apidata.embedurl"><span class="mobilehide">Share </span><i class="fas fa-share-square"></i></a>
  </div>
</div>
</template>

<script>
import "@babel/polyfill";
import axios from 'axios';
import videojs from 'video.js';
import 'wavesurfer.js';
import 'videojs-wavesurfer';
import 'videojs-vtt-thumbnails';
import lunr from 'lunr';
require('videojs-offset');
import {parse, toSeconds} from 'iso8601-duration'
import webvtt from 'node-webvtt';
var _ = require('lodash');
require('videojs-seek-buttons');

export default {
  name: 'avviewer',
  props: {
    avapi: String,
    starttime: String,
    endtime: String,
    time: String,
    type: String,
    writeapi: String,
    captionurl: String,
    avurl: String,
    existingeditors: String
  },
  data: function() {
    return {
      apidata: {},
      player: '',
      captions: {},
      searchshown: false,
      searchterm: '',
      index: '',
      searchresults: [],
      currentcapindex: -1,
      openbuttonclick: false,
      mediaid: '',
      pauseontyping: true,
      editor: '',
      showEmbedCode: false,
      shareparams: {
        'time': {},
        'starttime': {},
        'endtime': {}
      },
      issrt: false
    }
  },
  watch: {
    searchterm: function(newVal, oldVal) {
      if (newVal != oldVal && newVal == ''){
        this.updateSearch();
      }
    },
    'apidata.captions': function() {
      if (this.apidata.captions && this.apidata.captions['id']){
        this.issrt = this.apidata.captions['id'].indexOf('srt') > -1;
      }
    }
  },
  async mounted(){
    this.mediaid = `M${Math.random().toString().match(/[A-Za-z0-9]+/gm).join("")}`;
    this.editor = this.existingeditors ? this.existingeditors : '';
    if (this.avapi){
      await axios.get(this.avapi).then(response => {
        this.apidata = response.data;
        if (this.captionurl) {
          this.apidata.captions = {'id': this.captionurl};
        }
      })
      this.createViewer(this.mediaid);
    } else if (this.avurl){
      var vue = this;
      const slug = this.avurl.split('/').slice(-1)[0].match(/[A-Za-z0-9]+/gm).join("");
      this.apidata = {'type': 'video', 'avmaterial': [{'id': this.avurl}], 'id': this.mediaid, 'slug': slug};
      if (this.captionurl) {
        this.apidata.captions = {'id': this.captionurl};
      }
      setTimeout(function () {
        vue.createViewer(vue.mediaid);
      }, 1000);
    }
  },
  directives: {
    focus: {
      // directive definition
      inserted: function (el) {
        el.focus()
      }
    }
  },
  methods : {
    buildAfterShown: function(entries=false){
      const id = entries ? entries[0].target.id : this.mediaid;
      this.createViewer(id)
    },
    createViewer: function(id){
      const viewerelem = document.getElementById(id);
      if (viewerelem && viewerelem.offsetHeight == 0){
        var buildAfterShown = this.buildAfterShown;
        this.resizeObserver = new ResizeObserver(entries => 
          buildAfterShown(entries)
        )
        this.resizeObserver.observe(viewerelem)
      } else if (this.resizeObserver) {
        this.resizeObserver.disconnect();
      }
      if (viewerelem && viewerelem.tagName == 'VIDEO' && viewerelem.offsetHeight > 0){
        var options = {playbackRates: [0.5, 1, 1.5, 2],
          fluid: true,
          responsive: true, userActions: {hotkeys: true}
          };
        if (this.apidata.type.indexOf('Audio') > -1 && this.apidata.waveform){
          options['plugins'] = {
            wavesurfer: {
                debug: true,
                waveColor: '#CC0000',
                progressColor: 'white',
                cursorColor: 'darkgrey',
                mediaType: 'video',
                cursorWidth: 2,
                normalize: true,
                barHeight: 15,
                fluid: true,
                responsive: true,
                hideScrollbar: true
            }
          }
        }
        var vue = this;
        this.player = videojs(id, options, function onPlayerReady() {
          document.getElementsByClassName('video-js')[0].appendChild(document.getElementById('searchcontainer'));
          var srcs = []
          for (var av=0; av<vue.apidata.avmaterial.length; av++){
            const avitem = vue.apidata.avmaterial[av];
            var srcdict = {'src': avitem['id'], 'type': avitem['format']}
            if (vue.apidata.waveform && vue.apidata.type.indexOf('Audio') > -1){
              srcdict['peaks'] = vue.apidata.waveform['id'];
            }
            srcs.push(srcdict)
          }
          this.src(srcs)
          if (vue.starttime || vue.endtime) {
            this.offset({
              start: vue.starttime,
              end: vue.endtime,
              restart_beginning: true //Should the video go to the beginning when it ends
            });
          }

          this.on('loadedmetadata', function(){
            if (vue.time){ 
              this.currentTime(parseFloat(vue.time))
            }
            if(!vue.apidata.captions && !vue.captions.cues && vue.type == 'editor') {
              const duration = this.duration();
              vue.populateEmptyCaptions(duration);
            }
          });

          if (this.textTracks().length > 0){
            this.textTracks()[0].mode = 'showing'
          }     
        });
        
        this.addSeekButtons();
        this.player.on('timeupdate', function(){
          var cap = vue.searchresults.filter(element => (element.start <= this.currentTime() && this.currentTime() <= element.end))
          var index = vue.searchresults.indexOf(cap[0]);
          if (vue.type == 'editor') {
            vue.scrollTo('active')
          }
          if (vue.openbuttonclick || index != vue.currentcapindex){
            vue.activeWordScroll();  
          }
          vue.openbuttonclick = false;
          vue.currentcapindex = index;
        })
        this.apidata.sprites ? this.player.vttThumbnails({'src': this.apidata.sprites['id'], showTimestamp: true}) : '';
        if (this.apidata.captions){
          this.getCaptionData()
        } else if (this.type == 'editor' && this.apidata.duration) {
          const duration = toSeconds(parse(this.apidata.duration));
          this.populateEmptyCaptions(duration)
        }
      }
    },
    activeWordScroll: function(){
      if (this.searchshown){
        this.scrollTo("activecaption");
      }
    },
    scrollTo: function(classname){
      var activeword = document.getElementsByClassName(classname)[0];
      activeword ? activeword.scrollIntoView({
        behavior: 'auto',
        block: 'center',
        inline: 'center'
      }) : null;
    },
    goToTime: function(time){
      this.player.currentTime(time.toString());
    },
    createVTTFile: function() {
      try {
        const compile = webvtt.compile(this.captions);
        return compile
      }
      catch(err) {
        const caperrors = this.captions.errors.map(elem => elem.message);
        var message = err.message;
        if (caperrors.length > 0){
          message += `\nPlease look at the webvtt file for the following problem: ${caperrors.join("\n")}`
        }
        alert(message)
      }  
    },
    addSeekButtons: function() {
      this.player.seekButtons({
        forward: 10,
        back: 10
      });
    },
    pausePlayer: function() {
      if (this.pauseontyping) {
        this.player.pause()
      }
    },
    populateEmptyCaptions: function(duration) {
      var emptycaps = 'WEBVTT\n\n'
      const track = this.player.addTextTrack('captions', 'display')
      for (var bc=0; bc<duration; bc=bc+5){
        const startime = bc == 0 ? bc : bc+.001;
        const endtime = bc+5 >= duration ? duration : bc+5;
        emptycaps += `${this.convertToHMS(startime)} --> ${this.convertToHMS(endtime)}\n \n\n`
        if (bc+5 >= duration) {
          emptycaps += `${this.convertToHMS(startime)} --> ${this.convertToHMS(endtime)}\n \n\n`
        }
        track.addCue(new VTTCue(startime, endtime, ""));
      }
      this.populateCaptions(emptycaps)
    },
    updateTime: function(caption, field, index) {
      var highestvalue = ''
      var lowestvalue = ''
      if (field == 'start') {
        lowestvalue = index != 0 ? this.captions.cues[index-1]['start'] : 0
        highestvalue = caption['end']
      } else {
        lowestvalue = caption['start']
        highestvalue = this.captions.cues.length != index && index != 0 ? this.captions.cues[index+1]['start'] : this.player.duration();
      } 
      let newtime = this.convertToSeconds(caption[`${field}Time`])
      if (newtime && newtime > highestvalue) {
        newtime = highestvalue;
      }
      if (newtime && newtime < lowestvalue) {
        newtime = lowestvalue;
      }
      if (newtime){
        caption[field] = newtime;
        this.$set(caption, `${field}Time`, this.convertToHMS(newtime))
        this.$set(this.captions.cues, index, caption)
      }
      this.goToTime(caption[field])
      this.updateCaptions(index);
    },
    deleteCaption: function(index){
      var confirmation = confirm('Are you sure you want to delete?')
      if (confirmation){
        this.captions.cues.splice(index, 1);
        const track = this.player.textTracks()[0];
        if (track.cues[index]) {
          track.removeCue(track.cues[index])
          track.mode = 'showing'
        }
      }
    },
    addCaption: function(index){  
      const start = this.captions.cues[index]['end'] + 0.001;
      const end = this.captions.cues[index+1] ? this.captions.cues[index+1]['start'] : start + 4.999;
      const startTime = this.convertToHMS(start);
      const endTime = this.convertToHMS(end);
      if (start != end && (end - start) > 1){
        var captiondict = {"identifier": "", "start": start, "end": end, "text": "","startTime": startTime, "endTime": endTime, "styles": ""}
        this.captions.cues.splice(index+1, 0, captiondict)
      }
      this.updateCaptions(index)
    },
    updateCaptions: function(index) {
      const changedcap = this.captions.cues[index]
      if (changedcap.text.indexOf('\n\n') > -1){
        changedcap.text = changedcap.text.replace("\n\n", "\n")
        alert('You can not have two newlines in a WEBVTT file. We have removed the extra line you added.')
      }
      if(this.player.textTracks().length == 0){
        this.player.addTextTrack('caption', 'display')
      }
      const track = this.player.textTracks()[0];
      if (!track.cues[index]) {
        track.addCue(new VTTCue(1, 5, ""));
      }
      track.cues[index]['startTime'] = changedcap.start
      track.cues[index]['endTime'] = changedcap.end
      track.cues[index]['text'] = changedcap.text
      track.mode = 'showing'
    },
    copyEmbedUrl: function(id) {
      var copyText = document.querySelector(`#${id}`);
      copyText.select();
      document.execCommand("copy");
      const copybutton = document.getElementById('copyButton');
      copybutton.innerText = 'COPIED!';
      setInterval(function() {copybutton.innerText = 'COPY';}, 6000)
    },
    switchEmbed: function(){
      this.showEmbedCode = !this.showEmbedCode; 
      const copybutton = document.getElementById('copyButton'); 
      copybutton.innerText = 'COPY';
    },
    openShareModal: function() {
      this.player.pause();
      this.$set(this.shareparams['time'], 'value', this.convertToHMS(this.player.currentTime()));
      if (!this.shareparams['starttime']['value']){
        const modalstarttime = this.starttime ? parseInt(this.starttime) : 0;
        this.$set(this.shareparams['starttime'], 'value', this.convertToHMS(modalstarttime));
      }
      if (!this.shareparams['endtime']['value']){
        const modalendtime = this.endtime ? parseInt(this.endtime) : this.player.duration();
        this.$set(this.shareparams['endtime'], 'value', this.convertToHMS(modalendtime));
      }
      this.$modal.show('share');
    },
    writeToApi: function() {
      var file = this.createVTTFile();
      if (file){
        axios.post(this.writeapi, {
          filename: this.apidata.slug,
          contents: file,
          editor: this.editor ? this.editor : 'human'
        })
        .then(function (response) {
          alert('Success. The caption was successfully sent to your API')
          console.log(response)
        })
        .catch(function (error) {
          alert('There was an error send this caption to the api provided')
          console.log(error);
        });
      }
    },
    downloadFile: function(file, filetype) {
      const blob = new Blob([file], {type: 'application/vtt'})
      const e = document.createEvent('MouseEvents'),
      a = document.createElement('a');
      a.download = `${this.apidata.slug}.${filetype}`;
      a.href = window.URL.createObjectURL(blob);
      a.dataset.downloadurl = ['text/json', a.download, a.href].join(':');
      e.initEvent('click', true, false, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
      a.dispatchEvent(e);
    },
    downloadVTT: function() {
      var file = this.createVTTFile();
      if (file){
        this.downloadFile(file, 'vtt');
      }
    },
    convertToSeconds: function(time) {
      var seconds = new Date('1970-01-01T' + time + 'Z').getTime() / 1000;
      return seconds
    },
    convertToHMS: function(time) {
      var seconds = new Date(time*1000).toISOString().substr(11, 8);
      return `${seconds}.${time.toFixed(3).toString().split('.').slice(-1)[0]}`
    },
    skipTo: function(dictitem) {
      this.goToTime(dictitem.start)
      this.searchshown = !this.searchshown;
    },
    createButton: function(){
      var vue = this;
      var Button = videojs.getComponent('Button');
      var newButton = videojs.extend(Button, {
        constructor: function() {
          Button.apply(this, arguments);
          this.addClass('search-icon');
          this.controlText("Search Captions");
          this.addClass( 'fa' );
          this.addClass( 'fa-toggle-off' );
        },
        buildCSSClass: function() {
          return "vjs-icon-custombutton vjs-search-transcript vjs-button";
        },
        handleClick: function() {
          vue.searchshown = !vue.searchshown;
          vue.openbuttonclick = true;
          vue.player.currentTime(vue.player.currentTime());
        }
      });
      videojs.registerComponent('newButton', newButton);
      this.player.getChild('controlBar').addChild('newButton', {tabIndex: 1});
    },
    createIndex: function(data){
      this.index = lunr(function () {
        this.field('id')
        this.field('text')
        for (var i=0; i<data.length; i++){
          this.add({
            "id": data[i].start,
            "text": data[i].text
          })
        }
      })
    },
    updateSearch: function(){
      var results = this.index.search(this.searchterm)
      var updatecaptions = []
      for (var j=0; j<results.length; j++){
        var matches = this.captions.cues.filter(el=>el.start == results[j].ref);
        updatecaptions = updatecaptions.concat(matches)
      }
      this.searchresults = updatecaptions.length > 0 ? updatecaptions : [{'text': 'No Results'}];
    },
    populateCaptions: function(text){
      if (this.issrt) {
        text = 'WEBVTT\n\n' + text.replace(/(\d\d:\d\d:\d\d),(\d\d\d) --> (\d\d:\d\d:\d\d),(\d\d\d)/g, '$1.$2 --> $3.$4');
      }
      var data = webvtt.parse(text, { meta: true,  strict: false});
      if (data.errors.length > 0){
        const caperrors = data.errors.map(elem => elem.message)
        alert(`It looks like there might be a problem with your webvtt file.\n 
        Your updates might not be able to be saved if you are seeing this message.\n
        Please check your webvtt file and fix the problem that occur: ${caperrors.join("")}`)
      }
      if (data.cues.length == 0 && this.type == 'editor') {
        const duration = this.apidata.duration ? toSeconds(parse(this.apidata.duration)) : this.player.duration();
        this.populateEmptyCaptions(duration);
        return;
      }
      this.captions = data;
      if (data.cues.length > 0){
        if (this.issrt) {
          var track = this.player.addTextTrack('captions', 'display');
          track.mode = 'showing';
        }
        for (var i=0; i<this.captions.cues.length; i++){
          const cue = this.captions.cues[i];
          if (cue['text'] == ' '){
            cue['text'] = '';
          }
          cue['startTime'] = this.convertToHMS(cue['start'])
          cue['endTime'] = this.convertToHMS(cue['end'])
          if (this.issrt){
            track.addCue(new VTTCue(cue['start'], cue['end'], cue['text']));
          }
        }
        this.createButton();
        this.createIndex(this.captions.cues);
        this.updateSearch();
      }
    },
    getCaptionData: function(){
      axios.get(this.apidata.captions['id']).then(response => {
        this.populateCaptions(response.data)
      });
    },
    sort: function(captions) {
      var sortedObjs = _.sortBy(captions, 'start' );
      return sortedObjs
    }
  },
  computed: {
    playerCurrentTime: function() {
      return this.player.currentTime();
    },
    downloadAVLink: function() {
      const mpmovie = this.apidata.avmaterial.filter(element => element['format'] && element['format'].indexOf('mp') > -1);
      var movie = mpmovie.length > 0 ? mpmovie : this.apidata.avmaterial;
      movie = movie[0]['id'];
      const extension = movie.split('.').pop();
      return {'link': movie, 'format': extension}
    },
    embedUrl: function() {
      const embedurl = new URL(this.apidata.embedurl);
      for (var key in this.shareparams) {
        var dict = this.shareparams[key];
        if (dict['checked']){
          embedurl.searchParams.append(key, this.convertToSeconds(dict['value']));
        }
      }
      return embedurl.href;
    },
    embedCode: function() {
      return `<iframe src="${this.embedUrl}"></iframe>`
    }
  }
}
</script>

<style>
@import url('https://use.fontawesome.com/releases/v5.5.0/css/all.css');
@import '~video.js/dist/video-js.css';
@import '~videojs-vtt-thumbnails/dist/videojs-vtt-thumbnails.css';
@import '~videojs-seek-buttons/dist/videojs-seek-buttons.css';
@import '~videojs-wavesurfer/dist/css/videojs.wavesurfer.css';
video {
  max-width: 100%;
}

.captionbutton {
  background: none;
	color: inherit;
	border: none;
	font: inherit;
	cursor: pointer;
	outline: inherit;
  display: block!important;
  padding: 5px;
  text-align: -webkit-left;
  text-align: left;
  width: 100%;
  font-size: .8em;
}

.videocontainer {
  border: 1px solid black;
  display: inline-block;
  position: relative;
  width: 100%;
}

.videoplayer {
  width: 100%;
  height: 100%;
  text-align: center;
  display: inline-block;
  justify-content: center;
}

.editorplayer {
  display: inline-flex!important;
}

#searchcontainer {
  position: absolute;
  left: 0px;
  top: 0px;
  font-size: 20px;
  font-family: Helvetica;
  color: #FFF;
  z-index:19;
  padding: 0px 5px 0px;
  height: calc(100% - 1.45em);
}

.visiblesearch {
  width: 100%;
  height: 100%;
  background-color: rgba(50, 50, 50, 0.89);
  color:white;
}

#captionlist {
  height: 90%;
  overflow: scroll;
  position: absolute;
  top: 10%;
  width: calc(100% - 10px);
}

.vjs-search-transcript {
  font-family: 'Font Awesome\ 5 Free';
  font-weight: normal;
  font-style: normal;
  cursor: pointer;
}
.vjs-search-transcript:before {
  content: '\f002';
  font-weight: 900;
}

.closebutton {
  float: right;
  width: auto;
}

.stickyitem {
  position: absolute;
  height: 10%;
  width: calc(100% - 20px);
}

.searchterminput {
  margin-top: 1%;
  font-size: .8em;
  color: black;
  max-width: 200px;
}

.clearsearchterm {
  position:absolute;
  margin-left: 32px;
  z-index:200;
  color: black!important;
  margin-top: calc(1% + 3px);
}

.audio_1_0_end-dimensions {
  width: 700px;
  height: 422px;
}

.editor > * {
  padding: 5px;
}

.editview {
  width: 50%;
}
.editor {
  width: 50%;
  height: 422px;
  overflow: auto;
  display: inline-flex;
  flex-direction: column;
}

#editorcontent .active, .activecaption {
  background-color: maroon!important;
}

.timebutton {
  background:none;
  border:none;
  margin:0;
  padding:0;
  cursor: pointer;
  padding: 5px;
}

.editor textarea {
  width: 86%;
  height: auto;
}

.editorline {
  width: 100%;
  display: inline-flex;
  padding: 5px 0px;
}

.editor button {
  width: max-content;
}

.downloadbuttons {
  position: sticky;
  top: 0;
  display: inline-block;
  z-index: 2;
  background: white;
}

.downloadbuttons > * { 
  position: relative;
}
.downloadbuttons button {
  background-color: darkblue; /* Green */
  border: none;
  color: white;
  padding: 15px 32px;
  text-align: center;
  text-decoration: none;
  font-size: 16px;
  margin: 4px 2px;
  cursor: pointer;
  width: auto;
}

#editorcontent {
  position: relative;
}

.downloadlinks {
  display: block;
}

.btn {
  -webkit-user-select: none;
  margin-right: 20px;
  border: 1px solid rgb(204, 204, 204);
  background-color: rgb(255, 255, 255);
  box-sizing: border-box;
  color: rgb(51, 51, 51);
  cursor: pointer;
  display: inline-block;
  padding-bottom: 6px;
  padding-left: 12px;
  padding-right: 12px;
  padding-top: 6px;
  text-align: center;
  text-decoration: none;
  vertical-align: middle;
  white-space: nowrap;
}

.vjs-vtt-thumbnail-time {
  font-size: 2em;
}

.vjs-text-track-settings {
  height: 100%;
}

.resultstime {
  width: 25%;
  display: inline-block;
  word-wrap: break-word;
}

.resultstext {
  width: 75%;
  display: inline-block;
  vertical-align: top;
  word-wrap: break-word;
}

.editview .video-js {
  width: 100%!important;
  height: 100%!important;
}

.video-js {
  width: 100%!important;
}

.submitbutton {
  -webkit-border-radius: 5px;
  -moz-border-radius: 5px;
  border-radius: 5px;
  background-image: -webkit-gradient(linear, left bottom, left top, color-stop(0.16, rgb(207, 207, 207)), color-stop(0.79, rgb(252, 252, 252)))!important;
  background-image: -moz-linear-gradient(center bottom, rgb(207, 207, 207) 16%, rgb(252, 252, 252) 79%)!important;
  background-image: linear-gradient(to top, rgb(207, 207, 207) 16%, rgb(252, 252, 252) 79%)!important; 
  padding: 3px;
  border: 1px solid #000!important;
  color: black!important;
  text-decoration: none!important;
  vertical-align: bottom;
  margin-left: 3px;
}

.captionbuttons {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 10px;
}

.timecodes {
  justify-content: flex-start;  
  display: flex;
  flex-direction: column;
}

.disabled {
  color: darkgray;
  cursor: not-allowed;
  pointer-events: none;
}

.video-js .vjs-current-time { 
  display: block!important; 
}

.vjs-time-divider {
  display: block !important;
}

.video-js .vjs-duration, .vjs-no-flex .vjs-duration {
  display: block !important;
}

.video-js .vjs-time-control {
  padding: 0px!important;
}

.video-js .vjs-text-track-cue { 
  font-size: 1.4em !important;
}

.vjs-modal-dialog.vjs-text-track-settings {
  height: 100%!important;
}
.vm--modal {
  width: 60%!important;
  margin: 0 auto;
  left: inherit!important;
  top: 10%!important;
}

.vm--container {
  position: absolute!important;;
}

.vm--overlay {
  background: none!important;;
  position: absolute!important;
}

.shareItems input[readonly], .shareItems textarea[readonly] {
  width: 82%;
}

.embed {
  padding: 10px;
  background: lightgrey;
  color: black;
  display: flex;
  align-items: center;
  display:absolute;
}

.embed input, .embed textarea, .embed input:focus, .embed textarea:focus{
  border: none;
  resize: none;
  background: lightgrey;
  color: black;
}

#copyButton {
  width: 16%;
  font-size: 14px;
  font-weight: bold;
  border: none;
  color: darkblue;
  background: lightgrey;
}

.closemodal {
  float:right;
  font-size:2em;
  padding:5px;
}
.vjs-hover {
  z-index: 20;
}

.vjs-wavedisplay{
  max-height: 100%;
}

.vjs-mouse-display .vjs-time-tooltip {
  font-size: 1.5em!important;
  top: calc(-3.4em + 1.4em)!important;
}


@media (max-width: 755px) {
  .captionbutton {
    font-size: 12px!important;
  }
}

@media (max-width: 460px) {
  .captionbutton {
    font-size: 12px!important;
  }
  .resultstime {
    width: 30%!important;
  }
  .resultstext {
    width: 70%!important;
  }
  .vm--modal {
    top: 6%!important;
    width: 100%!important;
    left: 0px!important;
    height: 150px!important;
    overflow: scroll;
  }
  .closemodal {
    font-size:1em;
  }
  .mobilehide {
    display: none;
  }
}
</style>
