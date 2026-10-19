{{flutter_js}}
{{flutter_build_config}}

// Same as Flutter's default loader, plus fading out the loading screen from
// index.html once the dashboard is running.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const splash = document.getElementById("splash");
    if (splash) {
      splash.classList.add("done");
      setTimeout(() => splash.remove(), 400);
    }
  },
});
