#include "embed.h"
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#ifdef _WIN32 /* Making standard input streams on Windows binary */
#include <windows.h>
#include <io.h>
#include <fcntl.h>
extern int _fileno(FILE *stream);
static void binary(FILE *f) { _setmode(_fileno(f), _O_BINARY); }
#else
static inline void binary(FILE *f) { UNUSED(f); }
#endif

static int load_default_or_file(embed_t *h, char *file)
{
	if(!file)
		return embed_load_buffer(h, embed_default_block, embed_default_block_size);
	return embed_load(h, file);
}

static int run(embed_t *h, bool load, FILE *in, FILE *out, char *iblk, char *oblk)
{
	if(load)
		if(load_default_or_file(h, iblk) < 0)
			embed_die("embed: load failed (input = %s)", iblk ? iblk : "(null)");
	return embed_forth(h, in, out, oblk);
}

static const char *help ="\
usage: ./embed -i in.blk -o out.blk file.fth\n\n\
Program: Embed Virtual Machine and eForth Image\n\
Author:  Richard James Howe\n\
License: MIT\n\
Site:    https://github.com/howerj/embed\n\n\
Options:\n\
  -i in.blk   load virtual machine image from 'in.blk'\n\
  -o out.blk  set save location to 'out.blk'\n\
  -h          display this help message and die\n\
  file.fth    read from 'file.fth'\n\n\
If no input Forth file is given standard input is read from. If no input\n\
block is given a built in version containing an eForth interpreter is\n\
used.\n\
";

static char *next(int *i, const int argc, char **argv)
{
	const int j = *i;
	if(j + 1 >= argc)
		embed_die("%s expects option", argv[j]);
	*i = j + 1;
	return argv[*i];
}

int main(int argc, char **argv)
{
	char *oblk = NULL, *iblk = NULL;
	FILE *in = stdin, *out = stdout;
	bool ran = false;
	int r = 0;
	binary(stdin);
	binary(stdout);
	binary(stderr);
	embed_t *h = embed_new();
	if(!h)
		embed_die("embed: new failed");
	for(int i = 1; i < argc; i++) {
		if(!strcmp("-i", argv[i])) {
			if(iblk)
				embed_die("embed: input block already set");
			iblk = next(&i, argc, argv);
			if(embed_load(h, iblk) < 0)
				embed_die("embed: load failed");
		} else if(!strcmp("-o", argv[i])) {
			if(oblk)
				embed_die("embed: output block already set");
			oblk = next(&i, argc, argv);
		} else if(!strcmp("-h", argv[i])) {
			embed_die("%s", help);
		} else {
			FILE *f = embed_fopen_or_die(argv[i], "rb");
			r = run(h, !ran, f, out, iblk, oblk);
			ran = true;
			fclose(f);
			if(r < 0)
				goto end;
		}
	}
	if(!ran)
		r = run(h, !ran, in, out, iblk, oblk);
end:
	embed_free(h);
	return r;
}
