AirliftOSX
==========

A preliminary OS X client for [Airlift](https://github.com/moshee/airlift), the self-hosted file upload and sharing service. The current implementation "just works" -- words that come to mind are *basic*, *bare-bones*, *buggy*, and *baffling*.

A binary download may be found under the [releases tab](https://github.com/moshee/AirliftOSX/releases).

### Usage

Launch the app and the icon should show up in your menu bar.

![Menu item](https://i.ktkr.us/v0jk.png)

Clicking on it should allow you to access the preferences; here, you need to set up the host, port, and password for your server.

Checking the box for appending the file extension will make the client tack the uploaded file's extension onto the returned URL, e.g. uploading file.gif returns http://i.example.com/g9D2.gif instead of http://i.example.com/g9D2.

![Preferences window](https://i.ktkr.us/SNyH.png)

Then, you can drag files onto the icon, use `Opt+Shift+4` to capture and upload a screenshot with the familiar screencapture interface, or `Opt+Shift+3` to upload a shot of the entire screen.

![Dragging](https://i.ktkr.us/j5TO.gif)

While a file is uploading, a "cancel upload" item will appear in the menu; click it to cancel the upload.

Clicking the "Oops!" item will delete the last item uploaded to the server.
