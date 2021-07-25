#!/usr/bin/env bash

INPUT_FILE=gemeenten.json
OUTPUT_FILE=gemeenten-simple.json
if [[ ! -f "$INPUT_FILE" ]]; then
    curl -s "https://service.pdok.nl/kadaster/bestuurlijkegebieden/wfs/v1_0?request=GetFeature&service=wfs&outputFormat=application/json&version=2.0.0&typeName=bestuurlijkegebieden:Gemeentegebied" -o $INPUT_FILE
    jq -c "." < $INPUT_FILE | sponge $INPUT_FILE
else
    echo "$INPUT_FILE exists, skipping download"
fi

rm -f $OUTPUT_FILE
ndjson-split 'd.features' < gemeenten.json | \
    geo2topo -n gemeenten=- | \
        toposimplify -p 15000 -f | \
            topoquantize 1e4 | \
                topo2geo gemeenten=- | \
                    ogr2ogr -f GeoJSON $OUTPUT_FILE /vsistdin/ "" -a_srs EPSG:28992 -nln gemeenten
cp $OUTPUT_FILE /mnt/c/Users/arbak/Downloads