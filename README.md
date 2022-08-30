### WWDC 2006 Animation

This is the source code to accompany the blog post at [https://saurabhs.org/wwdc-2006-core-animation](https://saurabhs.org/wwdc-2006-core-animation).

The only step required to run this project is to populate the `Images/` directory with album art jpegs, as I legally cannot include the album art in the repository. Since the grid is 5x8, I recommend adding ~40 album art jpegs. You can do this manually, or use a script I included to assist in this:

1. Install [sacad](https://github.com/desbma/sacad).
2. Create a file in the Images directory called `albums.txt`, with each line containing an artist and album name in quotes, like this:
```
"coldplay" "x&y"
"kanye west" "graduation"
```
3. Run `python3 download_albums.py albums.txt`, which will download the album artwork for each line.
