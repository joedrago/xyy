THREE = require 'three'
OrbitControls = require('three-orbit-controls')(THREE)
ColorProfile = require './ColorProfile'

GLOBAL_STEPS = 170

createEdge = (profile, p0, p1, mode) ->
  steps = GLOBAL_STEPS
  infos = new Array(steps * steps)

  geometry = new THREE.Geometry()
  for edgeStep in [0...steps]
    for intensityStep in [0...steps]
      edge = edgeStep / (steps-1)
      px = p0[0] + ((p1[0] - p0[0]) * edge)
      py = p0[1] + ((p1[1] - p0[1]) * edge)
      intensity = intensityStep / (steps-1)
      info = profile.calc(px, py, intensity, mode)
      infos[intensityStep + (edgeStep * steps)] = info
      geometry.vertices.push(new THREE.Vector3(info.x, info.y, info.z))

  for edgeStep in [1...steps]
    for intensityStep in [1...steps]
      trIndex = intensityStep + (edgeStep * steps)
      tlIndex = trIndex - 1
      blIndex = trIndex - steps - 1
      brIndex = trIndex - steps

      face = new THREE.Face3(trIndex, blIndex, tlIndex)
      face.vertexColors[0] = new THREE.Color(infos[trIndex].r, infos[trIndex].g, infos[trIndex].b)
      face.vertexColors[1] = new THREE.Color(infos[blIndex].r, infos[blIndex].g, infos[blIndex].b)
      face.vertexColors[2] = new THREE.Color(infos[tlIndex].r, infos[tlIndex].g, infos[tlIndex].b)
      geometry.faces.push(face)

      face = new THREE.Face3(blIndex, trIndex, brIndex)
      face.vertexColors[0] = new THREE.Color(infos[blIndex].r, infos[blIndex].g, infos[blIndex].b)
      face.vertexColors[1] = new THREE.Color(infos[trIndex].r, infos[trIndex].g, infos[trIndex].b)
      face.vertexColors[2] = new THREE.Color(infos[brIndex].r, infos[brIndex].g, infos[brIndex].b)
      geometry.faces.push(face)

  material = new THREE.MeshBasicMaterial {
    vertexColors: THREE.VertexColors
    # side: THREE.DoubleSide
    opacity: 1
    transparent: true
  }
  edge = new THREE.Mesh(geometry, material)
  return edge

createRoof = (profile, mode) ->
  steps = GLOBAL_STEPS
  infos = new Array(steps * steps)

  pr = profile.primaries.red
  pg = profile.primaries.green
  pb = profile.primaries.blue
  # pr ___ pb
  #   |  /
  #   | /
  #   |/
  # pg
  # for each edgeStep, derive two intermediate coords on the
  # pr-pg and pr-pb lines. lerp across that line.

  geometry = new THREE.Geometry()
  for rowStep in [0...steps]
    row = rowStep / (steps - 1)
    p0 = [
      pr[0] + ((pg[0] - pr[0]) * row)
      pr[1] + ((pg[1] - pr[1]) * row)
    ]
    p1 = [
      pr[0] + ((pb[0] - pr[0]) * row)
      pr[1] + ((pb[1] - pr[1]) * row)
    ]
    for colStep in [0...steps]
      col = colStep / (steps - 1)
      px = p0[0] + ((p1[0] - p0[0]) * col)
      py = p0[1] + ((p1[1] - p0[1]) * col)
      info = profile.calc(px, py, 1.0, mode)
      infos[colStep + (rowStep * steps)] = info
      geometry.vertices.push(new THREE.Vector3(info.x, info.y, info.z))

  for rowStep in [1...steps]
    for colStep in [1...steps]
      trIndex = colStep + (rowStep * steps)
      tlIndex = trIndex - 1
      blIndex = trIndex - steps - 1
      brIndex = trIndex - steps

      face = new THREE.Face3(trIndex, blIndex, tlIndex)
      face.vertexColors[0] = new THREE.Color(infos[trIndex].r, infos[trIndex].g, infos[trIndex].b)
      face.vertexColors[1] = new THREE.Color(infos[blIndex].r, infos[blIndex].g, infos[blIndex].b)
      face.vertexColors[2] = new THREE.Color(infos[tlIndex].r, infos[tlIndex].g, infos[tlIndex].b)
      geometry.faces.push(face)

      face = new THREE.Face3(blIndex, trIndex, brIndex)
      face.vertexColors[0] = new THREE.Color(infos[blIndex].r, infos[blIndex].g, infos[blIndex].b)
      face.vertexColors[1] = new THREE.Color(infos[trIndex].r, infos[trIndex].g, infos[trIndex].b)
      face.vertexColors[2] = new THREE.Color(infos[brIndex].r, infos[brIndex].g, infos[brIndex].b)
      geometry.faces.push(face)

  material = new THREE.MeshBasicMaterial {
    vertexColors: THREE.VertexColors
    # side: THREE.DoubleSide
    opacity: 1
    transparent: true
  }
  edge = new THREE.Mesh(geometry, material)
  return edge

class ColorSpace
  constructor: (@name, @primaries, @luminance) ->
    @profile = new ColorProfile(@primaries, @luminance)
    @meshes =
      linear: []
      scaled: []
      log: []
      gamma: []

    @meshes.linear.push createEdge(@profile, @primaries.red, @primaries.green, 'linear')
    @meshes.linear.push createEdge(@profile, @primaries.green, @primaries.blue, 'linear')
    @meshes.linear.push createEdge(@profile, @primaries.blue, @primaries.red, 'linear')
    @meshes.linear.push createRoof(@profile, 'linear')

    @meshes.scaled.push createEdge(@profile, @primaries.red, @primaries.green, 'scaled')
    @meshes.scaled.push createEdge(@profile, @primaries.green, @primaries.blue, 'scaled')
    @meshes.scaled.push createEdge(@profile, @primaries.blue, @primaries.red, 'scaled')
    @meshes.scaled.push createRoof(@profile, 'scaled')

    @meshes.log.push createEdge(@profile, @primaries.red, @primaries.green, 'log')
    @meshes.log.push createEdge(@profile, @primaries.green, @primaries.blue, 'log')
    @meshes.log.push createEdge(@profile, @primaries.blue, @primaries.red, 'log')
    @meshes.log.push createRoof(@profile, 'log')

    @meshes.gamma.push createEdge(@profile, @primaries.red, @primaries.green, 'gamma')
    @meshes.gamma.push createEdge(@profile, @primaries.green, @primaries.blue, 'gamma')
    @meshes.gamma.push createEdge(@profile, @primaries.blue, @primaries.red, 'gamma')
    @meshes.gamma.push createRoof(@profile, 'gamma')

    material = new THREE.LineBasicMaterial {
      color: 0x000000
    }
    geometry = new THREE.Geometry()
    geometry.vertices.push(
      new THREE.Vector3(@primaries.red[1], 0.001, @primaries.red[0])
      new THREE.Vector3(@primaries.green[1], 0.001, @primaries.green[0])
      new THREE.Vector3(@primaries.blue[1], 0.001, @primaries.blue[0])
      new THREE.Vector3(@primaries.red[1], 0.001, @primaries.red[0])
    )
    @lines = new THREE.Line(geometry, material)
    @label = makeTextSprite(@name, @primaries.green[1], 1, @primaries.green[0])

  addTo: (scene) ->
    for type of @meshes
      for mesh in @meshes[type]
        scene.add(mesh)
    scene.add(@lines)

  addLabelTo: (scene) ->
    scene.add(@label)

  showMeshes: (whichType) ->
    for type of @meshes
      s = (type == whichType)
      for mesh in @meshes[type]
        mesh.material.visible = s

    greenCoord = @profile.calc(@primaries.green[0], @primaries.green[1], 1, whichType)
    @label.position.set(greenCoord.x, greenCoord.y, greenCoord.z)

  showLines: (show) ->
    @lines.material.visible = show

  showLabel: (show) ->
    @label.material.visible = show

  setOpacity: (opacity) ->
    for type of @meshes
      for mesh in @meshes[type]
        mesh.material.opacity = opacity

clamp = (num, min, max) ->
  return if num <= min then min else if num >= max then max else num

makeTextSprite = (message, x, y, z, depthTest = false) ->
  canvas = document.createElement('canvas')
  dimensions = 256
  canvas.width = dimensions
  canvas.height = dimensions
  context = canvas.getContext('2d')
  context.font = 'Bold '+Math.floor(dimensions / 10)+'px monospace'
  context.textAlign = 'right'

  context.strokeStyle = '#000000'
  context.lineWidth = 4
  context.miterLimit = 2
  context.strokeText message, dimensions / 2, (dimensions / 2) - 2

  context.fillStyle = '#ffffff'
  context.fillText message, dimensions / 2, (dimensions / 2) - 2

  texture = new THREE.CanvasTexture(canvas)
  texture.needsUpdate = true
  spriteMaterial = new THREE.SpriteMaterial(
    map: texture
    depthTest: depthTest
  )
  sprite = new THREE.Sprite(spriteMaterial)
  sprite.scale.set 0.25, 0.25, 0.25
  sprite.position.set(x,y,z)
  return sprite

createChromaticityChart = ->
  # profile = new ColorProfile({
  #   red: [0.64, 0.33]
  #   green: [0.3, 0.6]
  #   blue: [0.15, 0.06]
  #   white: [0.3127, 0.3290]
  # }, 300)

  # chroma = document.getElementById('chroma')
  # ctx = chroma.getContext('2d')
  # ctx.fillStyle = 'white'
  # ctx.fillRect(0, 0, chroma.width, chroma.height)
  # for j in [0...chroma.height]
  #   for i in [0...chroma.width]
  #     x = clamp(i / (chroma.width-1), 0, 1)
  #     y = clamp(1.0 - (j / (chroma.height-1)), 0, 1)
  #     rgb = profile.rgb(x, y)
  #     if rgb != null
  #       color = [
  #         rgb[0] * 255
  #         rgb[1] * 255
  #         rgb[2] * 255
  #       ]
  #       ctx.fillStyle = "rgb(#{color[0]},#{color[1]},#{color[2]})"
  #       ctx.fillRect(i, j, 1, 1)
  # texture = new THREE.CanvasTexture(chroma)
  texture = new THREE.TextureLoader().load("1931.png")

  material = new THREE.MeshBasicMaterial {
    opacity: 1
    transparent: true
    map: texture
  }
  geometry = new THREE.Geometry()
  geometry.vertices.push(new THREE.Vector3(0,0,0))
  geometry.vertices.push(new THREE.Vector3(1,0,0))
  geometry.vertices.push(new THREE.Vector3(0,0,1))
  geometry.vertices.push(new THREE.Vector3(1,0,1))
  geometry.faces.push new THREE.Face3(2,1,0)
  geometry.faces.push new THREE.Face3(3,1,2)
  geometry.faceVertexUvs = [[[], []]]
  geometry.faceVertexUvs[0][0].push(new THREE.Vector2(1,0))
  geometry.faceVertexUvs[0][0].push(new THREE.Vector2(0,1))
  geometry.faceVertexUvs[0][0].push(new THREE.Vector2(0,0))
  geometry.faceVertexUvs[0][1].push(new THREE.Vector2(1,1))
  geometry.faceVertexUvs[0][1].push(new THREE.Vector2(0,1))
  geometry.faceVertexUvs[0][1].push(new THREE.Vector2(1,0))
  mesh = new THREE.Mesh(geometry, material)
  return {
    # chroma: chroma
    texture: texture
    mesh: mesh
  }

resizeRenderer = (renderer) ->
  windowAspectRatio = window.innerWidth / window.innerHeight
  wantedAspectRatio = 16 / 9
  aspectRatio = window.innerWidth / window.innerHeight
  console.log "aspectRatio #{aspectRatio}"
  if windowAspectRatio < wantedAspectRatio
    # portrait
    console.log "portrait"
    renderWidth = window.innerWidth
    renderHeight = Math.floor(window.innerWidth / wantedAspectRatio)
  else
    # landscape
    console.log "landscape"
    renderWidth = Math.floor(window.innerHeight * wantedAspectRatio)
    renderHeight = window.innerHeight

  # # is this better or worse?
  # renderWidth = window.innerWidth
  # renderHeight = window.innerHeight

  console.log "innerWidth #{window.innerWidth} innerHeight #{window.innerHeight} renderWidth #{renderWidth} renderHeight #{renderHeight}"


  renderer.setSize(renderWidth, renderHeight)

main = ->
  renderer = new THREE.WebGLRenderer()
  resizeRenderer(renderer)
  document.body.appendChild(renderer.domElement)

  window.addEventListener "resize", ->
    resizeRenderer(renderer)

  scene = new THREE.Scene()
  initialZoomInv = 2.3
  xOffset = 0.3
  yOffset = 0.2
  camera = new THREE.OrthographicCamera( xOffset + (initialZoomInv / - 2), xOffset + (initialZoomInv / 2), yOffset + (initialZoomInv * 9/16 / 2), yOffset + (initialZoomInv * 9/16 / - 2), 0.01, 10000 );
  # camera = new THREE.PerspectiveCamera(60, renderWidth / renderHeight, 0.1, 1000)

  scene.background = new THREE.Color(0x222222)

  axes = new THREE.AxesHelper(1)
  axes.material = new THREE.LineBasicMaterial {
    color: 0xffffff
    linewidth: 1
  }
  scene.add axes

  chart = createChromaticityChart()
  scene.add(chart.mesh)

  colorSpaces = []
  colorSpaces.push new ColorSpace("BT709", {
    red: [0.64, 0.33]
    green: [0.3, 0.6]
    blue: [0.15, 0.06]
    white: [0.3127, 0.3290]
  }, 80)
  colorSpaces.push new ColorSpace("P3", {
    red: [0.68, 0.32]
    green: [0.265, 0.690]
    blue: [0.150, 0.060]
    white: [0.3127, 0.3290]
  }, 80)
  colorSpaces.push new ColorSpace("BT2020", {
    red: [0.708, 0.292]
    green: [0.170, 0.797]
    blue: [0.131, 0.046]
    white: [0.3127, 0.3290]
  }, 80)
  colorSpaces.push new ColorSpace("P3 PQ", {
    red: [0.68, 0.32]
    green: [0.265, 0.690]
    blue: [0.150, 0.060]
    white: [0.3127, 0.3290]
  }, 10000)
  colorSpaces.push new ColorSpace("BT2020 PQ", {
    red: [0.708, 0.292]
    green: [0.170, 0.797]
    blue: [0.131, 0.046]
    white: [0.3127, 0.3290]
  }, 10000)

  colorSpacesEnabled = []
  for colorSpace in colorSpaces
    colorSpace.addTo(scene)
    colorSpace.showMeshes('none')
    colorSpacesEnabled.push true

  for colorSpace in colorSpaces
    colorSpace.addLabelTo(scene)

  toggleColorSpace = (index) ->
    colorSpacesEnabled[index] = !colorSpacesEnabled[index]

  mode = 'log'
  toggleColorSpace(1) # disable
  toggleColorSpace(2) # disable
  toggleColorSpace(3) # disable

  camera.zoom = 0.8
  camera.position.set(0, 0, 1)
  camera.updateProjectionMatrix()

  controls = new OrbitControls(camera, renderer.domElement)
  controls.target.set(0.3127, 0.25, 0.329)
  controls.minZoom = 0.5
  controls.maxZoom = 2
  controls.minPolarAngle = 0
  controls.maxPolarAngle = Math.PI / 2
  controls.autoRotate = true
  controls.enablePan = false
  controls.autoRotateSpeed = 1
  controls.enableDamping = true
  controls.dampingFactor = 0.25

  labels =
    linear: []
    scaled: []
    log: []
    gamma: []
  makeLabel = (mode, text, x, y, z) ->
    label = makeTextSprite(text, x, y, z, true)
    scene.add label
    labels[mode].push label

  makeLabel('log', "10 _",    0, ColorProfile.getLogLuminance(10 / 10000), 0)
  makeLabel('log', "80 _",    0, ColorProfile.getLogLuminance(80 / 10000), 0)
  makeLabel('log', "300 _",    0, ColorProfile.getLogLuminance(300 / 10000), 0)
  makeLabel('log', "1000 _",    0, ColorProfile.getLogLuminance(1000 / 10000), 0)
  makeLabel('log', "10,000 _",    0, ColorProfile.getLogLuminance(1), 0)

  makeLabel('linear', "1.0 _", 0, 1, 0)
  makeLabel('linear', "0.5 _", 0, 0.5, 0)
  makeLabel('scaled', "10,000 _", 0, 1, 0)
  makeLabel('gamma',  "1.0 _", 0, 1, 0)
  makeLabel('gamma',  "0.5 _", 0, Math.pow(0.5, 1.0 / 2.4), 0)
  makeLabel('gamma',  "0.25 _", 0, Math.pow(0.25, 1.0 / 2.4), 0)

  allowRotate = false
  showUpperLeftText = true
  showLabels = true

  rotate2 = 0
  rotate3 = 2

  document.addEventListener 'keydown', (event) ->
    # console.log event.key
    switch event.key
      when "1"
        toggleColorSpace(0)
      when "2"
        rotate2 = (rotate2 + 1) % 3
        switch rotate2
          when 0
            colorSpacesEnabled[1] = false
            colorSpacesEnabled[3] = false
          when 1
            colorSpacesEnabled[1] = true
            colorSpacesEnabled[3] = false
          when 2
            colorSpacesEnabled[1] = false
            colorSpacesEnabled[3] = true
      when "3"
        rotate3 = (rotate3 + 1) % 3
        switch rotate3
          when 0
            colorSpacesEnabled[2] = false
            colorSpacesEnabled[4] = false
          when 1
            colorSpacesEnabled[2] = true
            colorSpacesEnabled[4] = false
          when 2
            colorSpacesEnabled[2] = false
            colorSpacesEnabled[4] = true
      when "l"
        showLabels = !showLabels
      when "t"
        showUpperLeftText = !showUpperLeftText
      when "m"
        mode = switch mode
          when "linear" then 'scaled'
          when "scaled" then 'log'
          when "log"    then 'gamma'
          when "gamma"  then 'linear'
        console.log "mode #{mode}"
      when "n"
        mode = switch mode
          when 'scaled'   then "linear"
          when 'log'   then "scaled"
          when 'gamma'   then "log"
          when 'linear'   then "gamma"
        console.log "mode #{mode}"
      when "r"
        allowRotate = !allowRotate

  upperLeftTextCurrent = null
  upperLeftTextDiv = null
  updateUpperLeft = ->
    if showUpperLeftText
      upperLeftText = "Luminance Scale: #{mode}"
    else
      upperLeftText = ""

    if upperLeftTextDiv == null
      upperLeftTextDiv = document.createElement('div')
      upperLeftTextDiv.style.position = 'absolute'
      upperLeftTextDiv.style.whiteSpace = 'pre'
      #upperLeftTextDiv.style.zIndex = 1    # if you still don't see the label, try uncommenting this
      upperLeftTextDiv.style.width = 200
      upperLeftTextDiv.style.height = 200
      # upperLeftTextDiv.style.backgroundColor = "blue"
      upperLeftTextDiv.style.color = 'white'
      upperLeftTextDiv.style.fontSize = '1.2em'
      upperLeftTextDiv.style.fontWeight = 900
      upperLeftTextDiv.innerHTML = upperLeftText
      upperLeftTextDiv.style.top = 0 + 'px'
      upperLeftTextDiv.style.left = 0 + 'px'
      document.body.appendChild(upperLeftTextDiv)
    if upperLeftTextCurrent != upperLeftText
      upperLeftTextCurrent = upperLeftText
      upperLeftTextDiv.innerHTML = upperLeftTextCurrent

  animate = ->
    updateUpperLeft()

    vector = new THREE.Vector3()
    camera.getWorldDirection(vector)
    theta = Math.asin(-vector.y)
    if theta > 1
      chartOpacity = clamp((theta-1) / ((Math.PI/2)-1), 0, 1)
    else
      chartOpacity = 0
    chart.mesh.material.opacity = chartOpacity

    meshMode = mode
    if chartOpacity > 0.9
      meshMode = 'none'

    for labelMode of labels
      for label in labels[labelMode]
        label.material.visible = (meshMode == labelMode) and showLabels

    foundEnabled = false
    for colorSpace, index in colorSpaces
      if colorSpacesEnabled[index]
        colorSpace.showMeshes(meshMode)
        colorSpace.showLines(true)
        colorSpace.showLabel(showLabels)
      else
        colorSpace.showMeshes('none')
        colorSpace.showLines(false)
        colorSpace.showLabel(false)

      opacity = 1.0
      if foundEnabled
        opacity = 0.7
      colorSpace.setOpacity(opacity)
      if colorSpacesEnabled[index]
        foundEnabled = true

    controls.autoRotate = (meshMode != 'none') and allowRotate
    controls.update()

    requestAnimationFrame(animate)
    renderer.render(scene, camera)
  animate()

main()
