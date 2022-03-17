import { createApp } from 'vue'
import App from './App.vue'
import HttpClient from './services/HttpClient'

const app = createApp(App)
app.config.productionTip = false
app.provide('$http', HttpClient.httpClient)
app.mount('#app')
