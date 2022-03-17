<template>
<div>
    <Profile />
    <img alt="logo" src="./assets/logo.png"> GearOff &copy; 2022 - GearOff is a totally useless demo app.
</div>
</template>

<script>
import Profile from './components/Profile.vue'

export default {
  name: 'App',
  components: {
    Profile
  }
}
</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
