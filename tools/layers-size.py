#!/usr/bin/env python3

import json
import subprocess
import argparse

parser = argparse.ArgumentParser(description='Iterates on all of the image tags in an openshift namespace, and computes the total size')
parser.add_argument('-n', '--namespace', nargs=1, required=True, help='The openshift namespace')

args = parser.parse_args()

namespace = args.namespace[0]



istags = json.loads(subprocess.check_output(['oc', '-n', namespace, 'get', 'istag', '-o', 'json']))
layer_sizes = {}
tag_sizes = []
print('Found ', len(istags['items']), ' tags')
for tag in istags['items']:
  layers = json.loads(subprocess.check_output(['oc', '-n', namespace, 'get', 'istag', tag['metadata']['name'] , '-o', 'json']))['image']['dockerImageLayers']
  tag_size = 0
  for layer in layers:
    layer_sizes[layer['name']] = layer['size']
    tag_size += layer['size']

  tag_sizes.append(tag_size)
  print(sum(layer_sizes.values())/1000000, 'MB')
  print(sum(tag_sizes)/1000000, 'MB')
