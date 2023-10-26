CC		= gcc

CFLAGS		= -g -Wall -pedantic -Werror

LDFLAGS		= -g

OUT		= sh

OBJS		= sh.o list.o

main: $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) -o $(OUT)

clean:
	rm -f *.o sh core out
	rm -r test-dir-*

test: main
	PYTHONIOENCODING=utf8 python3 ./shell-test.py ./$(OUT)
