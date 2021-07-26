import 'ol/ol.css'; // eslint-disable-line
import GeoJSON from 'ol/format/GeoJSON'
import Map from 'ol/Map'
import View from 'ol/View'
import { Fill, Style } from 'ol/style'
import { Vector as VectorSource } from 'ol/source'
import { Tile as TileLayer, Vector as VectorLayer } from 'ol/layer'
import { getVectorContext } from 'ol/render'
import { getTopLeft, getWidth } from 'ol/extent.js'
import { get as getProjection, fromLonLat } from 'ol/proj'
import WMTSSource from 'ol/source/WMTS'
import WMTSTileGrid from 'ol/tilegrid/WMTS.js'
import gemeenten from './data/gemeenten-simple-4326.json'

// set map to hidden on initial load, to prevent flashing of map
document.getElementById('map').style.visibility = 'hidden'

function getHashValue (key) {
  const matches = location.hash.match(new RegExp(key + '=([^&]*)'))
  return matches ? matches[1] : null
}

const projection = getProjection('EPSG:3857')
const projectionExtent = projection.getExtent()
const size = getWidth(projectionExtent) / 256
const resolutions = new Array(20)
const matrixIds = new Array(20)
for (let z = 0; z < 20; ++z) {
  // generate resolutions and matrixIds arrays for WMTS
  resolutions[z] = size / Math.pow(2, z)
  matrixIds[z] = z
}
const brtaLayer = new TileLayer({
  className: 'brta',
  type: 'base',
  title: 'grijs WMTS',
  extent: projectionExtent,
  source: new WMTSSource({
    url: 'https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0',
    crossOrigin: 'Anonymous',
    layer: 'grijs',
    matrixSet: 'EPSG:3857',
    format: 'image/png',
    tileGrid: new WMTSTileGrid({
      origin: getTopLeft(projectionExtent),
      resolutions: resolutions,
      matrixIds: matrixIds
    }),
    style: 'default'
  })
})

const lufoLayer = new TileLayer({
  type: 'base',
  title: '2020_ortho25 WMTS',
  extent: projectionExtent,
  source: new WMTSSource({
    url: 'https://service.pdok.nl/hwh/luchtfotorgb/wmts/v1_0',
    crossOrigin: 'Anonymous',
    layer: '2020_ortho25',
    matrixSet: 'EPSG:3857',
    format: 'image/png',
    tileGrid: new WMTSTileGrid({
      origin: getTopLeft(projectionExtent),
      resolutions: resolutions,
      matrixIds: matrixIds
    }),
    style: 'default'
  })
})

const clipSource = new VectorSource({
  format: new GeoJSON()
})

clipSource.setLoader((extent, resolution, projection, success, failure) => {
  document.getElementById('map').style.visibility = 'visible'
  document.getElementById('title').innerText = ''
  const gmCode = getHashValue('gmcode')
  if (!gmCode) {
    failure()
    return
  }
  const features = gemeenten.features
  const featuresFilter = features.filter(x => x.properties.code === gmCode)
  console.log(featuresFilter.length)
  if (featuresFilter.length === 0) {
    failure()
    return
  }
  const olFeature = new GeoJSON().readFeature(featuresFilter[0], {
    dataProjection: 'EPSG:4326',
    featureProjection: 'EPSG:3857'
  })
  clipSource.clear()
  if (olFeature) {
    clipSource.addFeature(olFeature)
  }
  const gemNaam = featuresFilter[0].properties.naam
  const gemProvincie = featuresFilter[0].properties.ligtInProvincieNaam
  const gemCode = featuresFilter[0].properties.code
  document.getElementById('title').innerText = `Gemeente ${gemCode} - ${gemNaam} (Provincie ${gemProvincie})`
  success(olFeature)
})

const style = new Style({
  fill: new Fill({
    color: 'red'
  })
})

const clipLayer = new VectorLayer({
  style: null,
  source: clipSource
})

// Giving the clipped layer an extent is necessary to avoid rendering when the feature is outside the viewport
clipLayer.getSource().on('addfeature', function () {
  lufoLayer.setExtent(clipLayer.getSource().getExtent())
})

lufoLayer.on('postrender', function (e) {
  const vectorContext = getVectorContext(e)
  e.context.globalCompositeOperation = 'destination-in'
  clipLayer.getSource().forEachFeature(function (feature) {
    vectorContext.drawFeature(feature, style)
  })
  e.context.globalCompositeOperation = 'source-over'
})

const map = new Map({
  layers: [brtaLayer, lufoLayer, clipLayer],
  target: 'map',
  view: new View({
    center: fromLonLat([5.417633, 52.152916]),
    zoom: 8
  })
})

clipSource.on('featuresloadend', function (e) {
  console.log('featuresloadend')
  document.getElementById('errorMessage').innerText = ''
  document.getElementById('map').style.display = 'block'
  document.getElementById('error').style.display = 'none'
  const clipLayerExtent = clipSource.getExtent()
  const mapSize = map.getSize()
  const paddingX = parseInt(mapSize[0] * 0.05)
  const paddingY = parseInt(mapSize[1] * 0.05)
  map.getView().fit(clipLayerExtent, {
    size: mapSize,
    padding: [paddingY, paddingX, paddingY, paddingX]
  }
  )
})

// function to convert literal HTML string in DOM node
function htmlToElement (html) {
  const template = document.createElement('template')
  html = html.trim() // Never return a text node of whitespace as the result
  template.innerHTML = html
  return template.content.firstChild
}

clipSource.on('featuresloaderror', function (e) {
  const gmCode = getHashValue('gmcode')
  if (gmCode) {
    document.getElementById('errorMessage').style.color = 'red'
    document.getElementById('errorMessage').innerText = `ERROR: GEMEENTE MET CODE ${gmCode} BESTAAT NIET`
  } else {
    document.getElementById('errorMessage').style.color = 'black'
    document.getElementById('errorMessage').innerText = 'Zoek een gemeente:'
    history.pushState(undefined, undefined, '#home')
  }
  gemeenten.features.sort(function (a, b) {
    if (a.properties.naam < b.properties.naam) { return -1 }
    if (a.properties.naam > b.properties.naam) { return 1 }
    return 0
  })

  let options = ''
  gemeenten.features.forEach(ft => {
    const gmnaam = ft.properties.naam
    options += `<option value="${gmnaam}">${gmnaam}</option>`
  })

  if (!document.getElementById('input-gemeenten')) {
    const input = '<input id="input-gemeenten" list="gemeenten" placeholder="Start met typen...">'
    const dataList = `<datalist id="gemeenten">${options}</datalist>`

    const inputEl = htmlToElement(input)
    const datalistEl = htmlToElement(dataList)

    document.getElementById('error').append(inputEl)
    document.getElementById('error').append(datalistEl)

    inputEl.addEventListener('input', function (e) {
      const shownVal = e.target.value
      const options = document.getElementById('gemeenten').children
      let validVal = false

      // validate input, if input is valid option fromd datalist trigger change
      for (let i = 0; i < options.length; i++) {
        if (options[i].value === shownVal) {
          validVal = true
        }
      }
      if (!validVal) {
        return
      }

      const ft = gemeenten.features.filter(x => x.properties.naam === shownVal)[0]
      const gmcode = ft.properties.code
      history.pushState(undefined, undefined, `#gmcode=${gmcode}`)
      hashHandler(null)
    })
  } else {
    document.getElementById('input-gemeenten').value = ''
  }

  document.getElementById('map').style.display = 'none'
  document.getElementById('error').style.display = 'flex'
})
function hashHandler (e) {
  clipSource.refresh()
}
window.onhashchange = hashHandler
