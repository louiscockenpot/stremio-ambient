# Recompile libstremio-ambient.so (une version compilée est déjà dans le repo,
# `make -B` force la recompilation).
#   make                                            avec gcc ou clang
#   make CC="zig cc -target x86_64-linux-gnu.2.34"  sans compilateur installé

CFLAGS ?= -O2

libstremio-ambient.so: stremio-ambient.c
	$(CC) -shared -fPIC $(CFLAGS) -o $@ $<
