---
name: makefile-c
description: Generate a C/C++ Makefile for a project. Use when user asks to create a Makefile, scaffold a C project, or initialize a C/C++ build system.
---

# C/C++ Makefile Generator

Generate a Makefile using this structure and style. Replace values in `{{...}}` with project-specific values.

## Template

```makefile
# ------------------------ Project Metadata
NAME	:=	{{project_name}}
TARGET	:=	{{target_binary_or_library}}

# ------------------------ Directories
SRCDIR	:=	src
OBJDIR	:=	obj
INCDIR	:=	include

# ------------------------ Files
SRC	:=	{{source_files}}
OBJ	:=	$(addprefix $(OBJDIR)/, $(SRC:.c=.o))

# ------------------------ Toolchain & Flags
CC		:=	cc
AR		:=	ar
ARFLAGS	:=	rcs
RM		:=	rm -f
CFLAGS	:=	-Wall -Wextra -Werror -MMD -MP
CPPFLAGS:=	-I $(INCDIR)

# ------------------------ Build Settings
.DEFAULT_GOAL	:= all

PAD		?=	0
PAD2	:=	10
DEBUG	?=	0

ifeq ($(DEBUG),1)
CFLAGS	+=	-g
endif

# ------------------------ Colors & Format
RESET	:=	\033[0m
GREEN 	:=	\033[32m

define log
printf "%-*s %-*s %s..." $(PAD) "[$(NAME)]" $(PAD2) "$(1)" "$(2)"
endef

define logok
printf " %b\n" "$(GREEN)[OK]$(RESET)"
endef

# ------------------------ Rules & Targets
.PHONY: all
all: $(TARGET)

.PHONY: clean
clean:
	@if [ -d "$(OBJDIR)" ]; then \
		$(call log,Removing:,$(OBJDIR)/); \
		$(RM) -r $(OBJDIR); \
		$(call logok); \
	fi

.PHONY: fclean
fclean: clean
	@if [ -f "$(TARGET)" ]; then \
		$(call log,Removing:,$(TARGET)); \
		$(RM) $(TARGET); \
		$(call logok); \
	fi

.PHONY: re
re: fclean all

$(OBJDIR):
	@$(call log,Creating:,$@/)
	@mkdir -p $@
	@$(call logok)

$(TARGET): $(OBJ)
	@$(call log,Building:,$@)
	@$(AR) $(ARFLAGS) $@ $^
	@$(call logok)

$(OBJDIR)/%.o: $(SRCDIR)/%.c | $(OBJDIR)
	@$(call log,Compiling:,$(notdir $<))
	@$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<
	@$(call logok)

.DELETE_ON_ERROR:
-include $(OBJ:.o=.d)
```

## Style Rules

- Use tab-aligned `:=` assignments with comment section headers
- `PAD`/`PAD2` support aligned output when building as part of a larger project (parent Makefile passes `PAD`)
- `DEBUG=1` flag adds `-g` for debug builds
- `-MMD -MP` for automatic header dependency tracking
- Colorized log output with `[OK]` markers
- For executables: replace `$(AR) $(ARFLAGS) $@ $^` with `$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)`
- For libraries: use `ar rcs` (the default)
- `.DELETE_ON_ERROR` ensures partial builds don't leave broken objects
