# Makefile for u8tosj

AS	= has
ASFLAGS	= -w
LD	= hlk
LDFLAGS	=

SRCS	= u8tosj.s table.s
OBJS	= $(SRCS:.s=.o)
U8TOSJ_R = u8tosj.r
U8TOSJ_X = u8tosj.x
DOCS	= README.txt LICENSE

SRC_ZIP	= src.zip
U8TOSJ_ZIP = u8tosj.zip
ARCS	= $(SRC_ZIP) $(U8TOSJ_ZIP)


.PHONY: all clean

all: $(U8TOSJ_R)


$(U8TOSJ_ZIP): $(SRC_ZIP) $(DOCS) $(U8TOSJ_R)
	rm -f $@
	zip -9 $@ $^

$(SRC_ZIP): Makefile $(SRCS)
	rm -f $@
	zip -9 $@ $^

LICENSE: ../LICENSE $(U8TOSJ_R)
	./$(U8TOSJ_R) < $< > $@

README.txt: ../README.md $(U8TOSJ_R)
	./$(U8TOSJ_R) < $< > $@


$(U8TOSJ_R): $(OBJS)
	$(LD) $(LDFLAGS) -r -o $@ $^

$(U8TOSJ_X): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $^


clean:
	rm -f $(U8TOSJ_R) $(U8TOSJ_X) $(OBJS) $(DOCS) $(ARCS)


# EOF
