import Vue from 'vue'
import App from './App.vue'
import Empty from './Empty.vue'

import 'document-register-element/build/document-register-element';
import vueCustomElement from 'vue-custom-element'
import VModal from 'vue-js-modal'
import VueRouter from 'vue-router'
import avviewer from './components/avviewer.vue';

Vue.use(VModal)
Vue.config.productionTip = false

if (process.env.NODE_ENV == 'website'){
  Vue.use(VueRouter)
  var routes = [
    { path: '/', component: avviewer}
  ]
  
  var router = new VueRouter({
    routes, 
    mode: 'history'
  })
  new Vue({
    render: h => h(App),
    router
  }).$mount('#app')
} else {
new Vue({
  render: h => h(Empty)
}).$mount('#app')
}
Vue.use(vueCustomElement);
Vue.customElement('av-viewer', avviewer);
