<template>
  <div>
    <p>
      You are [id]:<input v-model="userId" placeholder="1234" /><button
        @click="fetchProfile"
      >
        Set
      </button>
    </p>
    <div class="container">
      <form>
        <div class="form-group">
          <label for="filePreview">Profile Image:</label>
        <div
          class="form-control previewBlock"
          @click="chooseFile"
          :style="{
            'background-image': `${filePreview ? 'url(' + filePreview + ')' : 'url(https://upload.wikimedia.org/wikipedia/commons/a/a1/Missing_image_icon_with_camera_and_upload_arrow.svg)'}`,
          }"
          id="filePreview"
        ></div>

        <div hidden>
          <input
            class="form-control form-control-lg"
            ref="fileInput"
            type="file"
            id="formFileLg"
            @input="selectImgFile"
            accept=".jpg, .jpeg, .png"
          />
        </div>
        </div>
        <div class="form-group">
          <label for="userEmail">Email:</label>
          <input
            class="form-control"
            type="text"
            v-model="userEmail"
            placeholder="me@example.com"
            id="userEmail"
          />
        </div>
        <div class="form-group">
          <label for="userName">Name:</label>
          <input
            class="form-control"
            type="text"
            v-model="userName"
            placeholder=""
            id="userName"
          />
        </div>
        <div class="form-group">
          <label for="userNickname">Nickname:</label>
          <input
            class="form-control"
            type="text"
            v-model="userNickname"
            placeholder=""
            id="userNickname"
          />
        </div>
      </form>
      <p>
        <button class="btn btn-primary" @click="onSave">Save</button>
        <button class="btn btn-danger" @click="onDeleteProfile">
          Delete Profile
        </button>
      </p>
      <p style="color: #e83e8c; font-weight: 900" ref="errorText"></p>
    </div>
  </div>
</template>

<script>
export default {
  inject: ["$http"],
  name: "GearOff",
  data() {
    return {
      userId: null,
      userEmail: "",
      userName: "",
      userNickname: "",
      filePreview: null,
    };
  },
  methods: {
    fetchProfile() {
      this.$http
        .get("profile/" + this.userId)
        .then((response) => {
          let profile = response.data;
          this.userNickname = profile.nickname;
          this.userEmail = profile.email;
          this.userId = profile.id;
          this.userName = profile.name;
        })
        .catch(function (error) {
          console.error(error.response);
        });
    },
    onSave() {
      const formData = new FormData();
      formData.append("files", this.filePreview);
      this.$http.post("profile/" + this.userId + "/image", formData).then(
        (response) => {
          console.log(response);
          this.$refs.errorText.innerText = "";
          this.fetchProfile();
        },
        (err) => {
          if (err.response.status == 400) {
            this.$refs.errorText.innerText = err.response.data;
          } else {
            this.$refs.errorText.innerText = err;
          }
        }
      );
    },
    chooseFile() {
      this.$refs.fileInput.click();
    },
    selectImgFile() {
      let fileInput = this.$refs.fileInput;
      let imgFile = fileInput.files;

      if (imgFile && imgFile[0]) {
        let reader = new FileReader();
        reader.onload = (e) => {
          this.filePreview = e.target.result;
        };
        reader.readAsDataURL(imgFile[0]);
        this.$emit("fileInput", imgFile[0]);
      }
    },
  },
};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
.form-group {
  text-align: left;
}

.text em {
  color: #e83e8c;
}

.ok {
  color: lightgreen;
  font-weight: bolder;
}

.nok {
  color: #e83e8c;
  font-weight: bolder;
}

.previewBlock {
  display: block;
  cursor: pointer;
  width: 300px;
  height: 280px;
  margin: 0 auto 20px;
  background-position: center center;
  background-size: cover;
}
</style>
