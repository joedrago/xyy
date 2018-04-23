THREE = require 'three'
OrbitControls = require('three-orbit-controls')(THREE)
ColorProfile = require './ColorProfile'

GLOBAL_STEPS = 256

createEdge = (profile, p0, p1) ->
  steps = GLOBAL_STEPS
  infos = new Array(steps * steps)

  geometry = new THREE.Geometry()
  for edgeStep in [0...steps]
    for intensityStep in [0...steps]
      edge = edgeStep / (steps-1)
      px = p0[0] + ((p1[0] - p0[0]) * edge)
      py = p0[1] + ((p1[1] - p0[1]) * edge)
      intensity = intensityStep / (steps-1)
      info = profile.calc(px, py, intensity)
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

createRoof = (profile) ->
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
      info = profile.calc(px, py, 1.0)
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
  constructor: (@primaries, @luminance) ->
    @enabled = false
    @profile = new ColorProfile(@primaries, @luminance)
    @meshes = []
    @meshes.push createEdge(@profile, @primaries.red, @primaries.green)
    @meshes.push createEdge(@profile, @primaries.green, @primaries.blue)
    @meshes.push createEdge(@profile, @primaries.blue, @primaries.red)
    @meshes.push createRoof(@profile)

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

  addTo: (scene) ->
    for mesh in @meshes
      scene.add(mesh)
    scene.add(@lines)
    @enabled = true

  enable: (e) ->
    console.log "colorspace #{@primaries.red[0]} enable #{e}"
    @enabled = e
    @showMeshes(@enabled)
    @lines.material.visible = e

  showMeshes: (s) ->
    for mesh in @meshes
      mesh.material.visible = s

  setOpacity: (opacity) ->
    for mesh in @meshes
      mesh.material.opacity = opacity

clamp = (num, min, max) ->
  return if num <= min then min else if num >= max then max else num

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

main = ->
  renderer = new THREE.WebGLRenderer()
  if window.innerWidth < window.innerHeight
    # portrait
    renderWidth = window.innerWidth
    renderHeight = Math.floor(window.innerWidth / 9 * 16)
  else
    # landscape
    renderWidth = Math.floor(window.innerHeight / 9 * 16)
    renderHeight = window.innerHeight
  renderer.setSize(renderWidth, renderHeight)
  document.body.appendChild(renderer.domElement)

  scene = new THREE.Scene()
  # camera = new THREE.PerspectiveCamera(60, renderWidth / renderHeight, 0.1, 1000)
  initialZoomInv = 2.3
  xOffset = 0.3
  yOffset = 0.2
  camera = new THREE.OrthographicCamera( xOffset + (initialZoomInv / - 2), xOffset + (initialZoomInv / 2), yOffset + (initialZoomInv * 9/16 / 2), yOffset + (initialZoomInv * 9/16 / - 2), 0.1, 1000 );
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
  colorSpaces.push new ColorSpace({
    red: [0.64, 0.33]
    green: [0.3, 0.6]
    blue: [0.15, 0.06]
    white: [0.3127, 0.3290]
  }, 10000)

  colorSpaces.push new ColorSpace({
    red: [0.64, 0.33]
    green: [0.3, 0.6]
    blue: [0.15, 0.06]
    white: [0.3127, 0.3290]
  }, 300)

  colorSpaces.push new ColorSpace({
    red: [0.708, 0.292]
    green: [0.170, 0.797]
    blue: [0.131, 0.046]
    white: [0.3127, 0.3290]
  }, 10000)

  for colorSpace, index in colorSpaces
    colorSpace.addTo(scene)
    colorSpace.enable(index == 0)

  controls = new OrbitControls(camera, renderer.domElement)
  controls.target.set(0.3127, 0.25, 0.329)
  camera.position.set(0, 0, 1)
  controls.minDistance = 1
  controls.maxDistance = 3
  controls.minPolarAngle = 0
  controls.maxPolarAngle = Math.PI / 2
  controls.autoRotate = true
  controls.autoRotateSpeed = 1
  controls.enableDamping = true
  controls.dampingFactor = 0.25

  allowRotate = true

  document.addEventListener 'keydown', (event) ->
    # console.log event.key
    switch event.key
      when "1"
        colorSpaces[0].enable(!colorSpaces[0].enabled)
      when "2"
        colorSpaces[1].enable(!colorSpaces[1].enabled)
      when "3"
        colorSpaces[2].enable(!colorSpaces[2].enabled)
      when "r"
        allowRotate = !allowRotate

  animate = ->
    vector = new THREE.Vector3()
    camera.getWorldDirection(vector)
    theta = Math.asin(-vector.y)
    if theta > 1
      chartOpacity = clamp((theta-1) / ((Math.PI/2)-1), 0, 1)
    else
      chartOpacity = 0
    chart.mesh.material.opacity = chartOpacity

    showMeshes = true
    if chartOpacity > 0.9
      showMeshes = false

    bigOpacity = 1
    if (colorSpaces[0].enabled or colorSpaces[1].enabled) and colorSpaces[2].enabled
      bigOpacity = 0.5
    if colorSpaces[2].enabled
      colorSpaces[2].setOpacity(bigOpacity)

    for colorSpace in colorSpaces
      if colorSpace.enabled
        colorSpace.showMeshes(showMeshes)

    controls.autoRotate = showMeshes and allowRotate
    controls.update()

    requestAnimationFrame(animate)
    renderer.render(scene, camera)
  animate()

main()
