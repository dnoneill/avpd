<template>
  <div id="app">
    <p>
      <label for="avmaterial">URL for AV material: </label>
      <input name="avmaterial" v-model="avmaterial">
    </p>
    <p>
      <label for="captions">URL for WEBVTT file (optional): </label>
      <input name="captions" v-model="captions">
    </p>
    <div v-if="avmaterial">
      <avviewer v-bind:key="avmaterial" v-bind:avurl="avmaterial" v-bind:captionurl="captions" type="editor"></avviewer>
    </div>
  </div>
</template>

<script>
import avviewer from './components/avviewer'
export default {
  name: 'app',
  components: {
    avviewer
  },
  data() {
    return ({
      avmaterial: '',
      captions: '',
      showcomp: false,
      avurl: ''
    })
  },
  watch: {
    captions: function() {
      this.$children[0]._data.apidata.captions = {'id':this.captions};
      this.$children[0].getCaptionData();
    }
  }
}
</script>

<style>
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
