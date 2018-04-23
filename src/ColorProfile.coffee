clamp = (num, min, max) ->
  return if num <= min then min else if num >= max then max else num

matrixMultiply = (m, v) ->
  return [
    (m[0][0] * v[0]) + (m[0][1] * v[1]) + (m[0][2] * v[2])
    (m[1][0] * v[0]) + (m[1][1] * v[1]) + (m[1][2] * v[2])
    (m[2][0] * v[0]) + (m[2][1] * v[1]) + (m[2][2] * v[2])
  ]

Determinant3x3 = (m) ->
  det = m[0][0] * (m[2][2] * m[1][1] - m[2][1] * m[1][2]) -
        m[1][0] * (m[2][2] * m[0][1] - m[2][1] * m[0][2]) +
        m[2][0] * (m[1][2] * m[0][1] - m[1][1] * m[0][2])
  return det

MtxInvert3x3 = (m) ->
  scale = 1.0 / Determinant3x3(m)

  i = [
    [0,0,0]
    [0,0,0]
    [0,0,0]
  ]

  i[0][0] =  scale * (m[2][2] * m[1][1] - m[2][1] * m[1][2])
  i[0][1] = -scale * (m[2][2] * m[0][1] - m[2][1] * m[0][2])
  i[0][2] =  scale * (m[1][2] * m[0][1] - m[1][1] * m[0][2])

  i[1][0] = -scale * (m[2][2] * m[1][0] - m[2][0] * m[1][2])
  i[1][1] =  scale * (m[2][2] * m[0][0] - m[2][0] * m[0][2])
  i[1][2] = -scale * (m[1][2] * m[0][0] - m[1][0] * m[0][2])

  i[2][0] =  scale * (m[2][1] * m[1][0] - m[2][0] * m[1][1])
  i[2][1] = -scale * (m[2][1] * m[0][0] - m[2][0] * m[0][1])
  i[2][2] =  scale * (m[1][1] * m[0][0] - m[1][0] * m[0][1])

  return i

deriveColorMatrix = (r, g, b, w) ->
  xr = r[0]
  yr = r[1]
  xg = g[0]
  yg = g[1]
  xb = b[0]
  yb = b[1]
  xw = w[0] / w[1]
  yw = 1.0
  zw = (1 - w[0] - w[1]) / w[1]
  m = [
    [ xr/yr, xg/yg, xb/yb ]
    [ 1.0, 1.0, 1.0 ]
    [ (1.0-xr-yr)/yr, (1.0-xg-yg)/yg, (1.0-xb-yb)/yb ]
  ]

  mi = MtxInvert3x3(m)

  sr = xw * mi[0][0] + yw * mi[0][1] + zw * mi[0][2]
  sg = xw * mi[1][0] + yw * mi[1][1] + zw * mi[1][2]
  sb = xw * mi[2][0] + yw * mi[2][1] + zw * mi[2][2]

  return [
    [ sr * m[0][0], sg * m[0][1], sb * m[0][2] ]
    [ sr * m[1][0], sg * m[1][1], sb * m[1][2] ]
    [ sr * m[2][0], sg * m[2][1], sb * m[2][2] ]
  ]

BT709_TO_XYZ = deriveColorMatrix([0.64, 0.33], [0.3, 0.6], [0.15, 0.06], [0.3127, 0.3290])

class ColorProfile
  constructor: (@primaries, @luminance) ->
    @toXYZ = deriveColorMatrix(@primaries.red, @primaries.green, @primaries.blue, @primaries.white)
    @fromXYZ = MtxInvert3x3(@toXYZ)

  rgb: (x,y) ->
    if y == 0
      return null
    intensity = 1
    XYZ = [
      (x * intensity) / y
      intensity
      ((1 - x - y) * intensity) / y
    ]
    # console.log "XYZ0 #{XYZ}"
    RGB = matrixMultiply(@fromXYZ, XYZ)
    # console.log "RGB0 #{RGB}"
    rgbMax = Math.max(RGB[0], Math.max(RGB[1], RGB[2]))
    RGB = [
      clamp(RGB[0] / rgbMax, 0, 1)
      clamp(RGB[1] / rgbMax, 0, 1)
      clamp(RGB[2] / rgbMax, 0, 1)
    ]
    return RGB

  xyMaxIntensity: (x, y) ->
    RGB = @rgb(x, y)
    if RGB == null
      return 0
    XYZ = matrixMultiply(@toXYZ, RGB)
    return XYZ[1]

  calc: (x, y, intensity) ->
    maxIntensity = @xyMaxIntensity(x, y)
    scaledIntensity = intensity * maxIntensity
    # console.log "calc #{x},#{y},#{intensity} got max #{maxIntensity}, scaled #{scaledIntensity}"
    XYZ = [
      (x * scaledIntensity) / y
      scaledIntensity
      ((1 - x - y) * scaledIntensity) / y
    ]
    RGB = matrixMultiply(@fromXYZ, XYZ)
    return {
      x: y
      y: scaledIntensity * (@luminance / 10000)
      z: x

      r: RGB[0]
      g: RGB[1]
      b: RGB[2]
    }

module.exports = ColorProfile
