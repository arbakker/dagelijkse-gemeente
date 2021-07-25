#!/usr/bin/env bash
set -euo pipefail -xT
PROGRAM_NAME=$0

WIDTH=1100
LAYERNAME=Gemeentegebied
SERVICE_URL="https://service.pdok.nl/kadaster/bestuurlijkegebieden/wfs/v1_0?service=WFS"
FT_NAME="bestuurlijkegebieden:${LAYERNAME}"

function get_nr_features(){
        WFS_HITS_URL="${SERVICE_URL}&request=GetFeature&typeName=${FT_NAME}&version=1.1.0&resultType=hits"
        curl -s "$WFS_HITS_URL" | grep numberOfFeatures | sed  -rn -e 's|.*numberOfFeatures="([0-9]+)".*|\1|p' 
}

uriencode() {
  s="${1//'%'/%25}"
  s="${s//' '/%20}"
  s="${s//'"'/%22}"
  s="${s//'#'/%23}"
  s="${s//'$'/%24}"
  s="${s//'+'/%2B}"
  s="${s//','/%2C}"
  s="${s//'/'/%2F}"
  s="${s//';'/%3B}"
  s="${s//'?'/%3F}"
  s="${s//'@'/%40}"
  s="${s//'['/%5B}"
  s="${s//']'/%5D}"
  s="${s//'<'/%3C}"
  s="${s//'>'/%3E}"
  printf %s "$s"
}

function gen_gemeente_map(){
    mode=$1
    filter=$2
    WFS_GET_FEATURE_URL="https://service.pdok.nl/kadaster/bestuurlijkegebieden/wfs/v1_0?request=GetFeature&service=wfs&typename=&count=1&outputFormat=application/json&version=2.0.0&typeName=${FT_NAME}"
    if [[ $mode == "index" ]]; then
        WFS_GET_FEATURE_URL="${WFS_GET_FEATURE_URL}&startIndex=${filter}"
    elif [[ "$mode" == "gm_code" ]];then
        filter="<Filter><PropertyIsEqualTo><PropertyName>code</PropertyName><Literal>${filter}</Literal></PropertyIsEqualTo></Filter>"
        WFS_GET_FEATURE_URL="${WFS_GET_FEATURE_URL}&Filter=${filter}"
        query=$(cut -d\? -f2 <<< "$WFS_GET_FEATURE_URL")
        url=$(cut -d\? -f1 <<< "$WFS_GET_FEATURE_URL")
        WFS_GET_FEATURE_URL="${url}?$(uriencode "$query")"
    fi
    FILENAME="/tmp/$(uuidgen).json"
 
    curl -s "$WFS_GET_FEATURE_URL" | ogr2ogr "$FILENAME" /vsistdin/ -makevalid # fix invalid geoms in bestuurlijkegebieden wfs
    BBOX=$(ogrinfo "$FILENAME" "$LAYERNAME" -so | grep "Extent:" | sed -rn 's|Extent: \(([0-9]+\.[0-9]+), ([0-9]+\.[0-9]+)\) - \(([0-9]+\.[0-9]+), ([0-9]+\.[0-9]+)\)|\1,\2,\3,\4|p')

    GEMEENTE_NAAM=$(ogrinfo "$FILENAME" "$LAYERNAME" -geom=NO | grep "naam (String)" | cut -d= -f2 | xargs -0)
    PROVINCIE_NAAM=$(ogrinfo "$FILENAME" "$LAYERNAME" -geom=NO | grep "ligtInProvincieNaam (String)" | cut -d= -f2 | xargs -0)
    GM_CODE=$(ogrinfo "$FILENAME" "$LAYERNAME" -geom=NO | grep "code (String)" | cut -d= -f2 | xargs -0)

    IFS=',' read -r -a BBOX_ARRAY <<< "$BBOX"

    minx=$(bc -l <<< "${BBOX_ARRAY[0]}")
    miny=$(bc -l <<< "${BBOX_ARRAY[1]}")
    maxx=$(bc -l <<< "${BBOX_ARRAY[2]}")
    maxy=$(bc -l <<< "${BBOX_ARRAY[3]}")

    deltax=$(bc -l <<< "$maxx-$minx")
    deltay=$(bc -l <<< "$maxy-$miny")

    bufferx=$(bc -l <<< "$deltax/50")
    buffery=$(bc -l <<< "$deltay/50")

    minx=$(bc -l <<< "$minx-$bufferx")
    miny=$(bc -l <<< "$miny-$buffery")
    maxx=$(bc -l <<< "$maxx+$bufferx")
    maxy=$(bc -l <<< "$maxy+$buffery")

    RATIO=$(bc -l <<< "$deltay/$deltax")
    HEIGHT=$(bc -l <<< "$WIDTH*$RATIO")

    CRS="EPSG:28992"
    GET_IMAGE_URL="https://service.pdok.nl/hwh/luchtfotorgb/wms/v1_0?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&EXCEPTIONS=XML&FORMAT=image%2Fpng&BBOX=$minx,$miny,$maxx,$maxy&WIDTH=${WIDTH}&HEIGHT=${HEIGHT}&LAYERS=Actueel_ortho25&crs=${CRS}"

    DATA_DIR="./data"
    mkdir -p $DATA_DIR
    OUTPUT_FILE="${DATA_DIR}/${GM_CODE}.png"
    curl -s "$GET_IMAGE_URL" | \
        gdal_translate -a_srs ${CRS} -a_ullr "$minx" "$maxy" "$maxx" "$miny" /vsistdin/ /vsistdout/ | \
            gdalwarp -r cubic -cblend 2 -dstalpha -cutline "$FILENAME" -cl "$LAYERNAME" /vsistdin/ /vsistdout/ | \
                gdal_translate -of PNG  /vsistdin/ /vsistdout/ | \
                    convert - \
                        -pointsize 30 \
                        -background 'rgba(0, 0, 0, 0)' \
                        -fill black \
                        -font "Noto-Mono" \
                        label:"Gemeente ${GM_CODE} - ${GEMEENTE_NAAM} (Provincie ${PROVINCIE_NAAM})" \
                        -gravity center \
                        -append \
                        "$OUTPUT_FILE"

    echo "Output saved in ${OUTPUT_FILE}"
    echo "Gemeenten: ${GEMEENTE_NAAM}"
}





if [ "$#" -lt 1 ]; then
    MODE=RANDOM
else
    MODE=$1
fi



case $MODE in  
    RANDOM )
        nr_features=$(get_nr_features)
        upper_index=$(bc <<< "$nr_features-1")
        start_index=$(shuf -i "0-$upper_index" -n1)
        gen_gemeente_map index "$start_index"
    ;;
    SINGLE )
        if [ "$#" -ne 2 ]; then
            echo "usage: ${PROGRAM_NAME} SINGLE <GM_CODE>"
            echo "  - GM_CODE: gemeentecode (viercijferige code)"
            exit 1
        fi
        GM_CODE="$2"
        gen_gemeente_map gm_code "$GM_CODE"
    ;;
    ALL )
        nr_features=$(get_nr_features)
        upper_index=$(bc <<< "$nr_features-1")

        start_index=${2:-0}

        for i in $(seq 0 "$upper_index"); do
            gen_gemeente_map index "$i"
        done
    ;;
    * )
        echo "usage: ${PROGRAM_NAME} <MODE>"
        echo "  - MODE: RANDOM, ALL, SINGLE (requires additional GM_CODE parameter)"
        exit 1
    ;;
esac  
