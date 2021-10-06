# Makefile for u8tosj

AS      = has
ASFLAGS	= -w
LD      = hlk
LDFLAGS	=
MKDIR_P = mkdir -p


OBJ_DIR = o
OBJS = $(OBJ_DIR)/u8tosj.o $(OBJ_DIR)/table.o

EXES = u8tosj.r u8tosj.x


.PHONY: all directories clean distclean

#all: directories u8tosj.r
all: directories u8tosj.x

directories: $(OBJ_DIR)

$(OBJ_DIR):
	$(MKDIR_P) $(OBJ_DIR)


u8tosj.r: $(OBJS)
	$(LD) $(LDFLAGS) -r -o $@ $^

u8tosj.x: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^


$(OBJ_DIR)/%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $^

$(OBJ_DIR)/u8tosj.o: u8tosj.s
$(OBJ_DIR)/table.o: table.s


clean:
	rm -f $(OBJS)

distclean:
	rm -f $(OBJS) $(EXES)
	rm $(OBJ_DIR)


# EOF
