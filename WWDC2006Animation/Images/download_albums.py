import os
import shlex
import sys

if len(sys.argv) < 2:
  print('Usage: python3 download_albums.py <albums-txt-file>')
  sys.exit(-1)

filename = sys.argv[1]
lines = open(filename).readlines()

for line in lines:
  line_components = shlex.split(line)
  artist, album = line_components[0], line_components[1]
  album_without_spaces = '-'.join(album.split())
  command = 'sacad "%s" "%s" 600 %s.jpg' % (artist, album, album_without_spaces)
  print(command)
  os.system(command)
