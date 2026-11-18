{{flutter_js}}
{{flutter_build_config}}

// La app se dibuja dentro de <div id="marbel-app"> (ver index.html), que ocupa
// la pantalla entera con CSS. Así el iPhone (app instalada) no deja una franja
// vacía abajo: el tamaño lo marca la caja, no lo que el iPhone dice que mide.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.getElementById('marbel-app'),
    });
    await appRunner.runApp();
  },
});
