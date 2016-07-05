#include "string.h"
#include "tty.h"
#include "io.h"

uint16_t *const VIDEO_MEMORY = (uint16_t *) 0xB8000;
const size_t VGA_HEIGHT = 25;
const size_t VGA_WIDTH  = 80;

// The current row and column we're on.
int terminal_row;
int terminal_column;

// The current colour of the output.
uint8_t terminal_colour;
// An array to hold all of the output characters. It starts at address VIDEO_MEMORY
uint16_t *terminal_buffer;

// I/O ports
unsigned short TTY_COMMAND_PORT = 0x3d4;
unsigned short TTY_DATA_PORT = 0x3d5;

// I/O port commands
unsigned char TTY_HIGH_BYTE_CMD = 14;
unsigned char TTY_LOW_BYTE_CMD = 15;

// Set the foreground and background of all output starting when this function
// is called
static uint8_t makeColour(enum COLOUR fg, enum COLOUR bg) {
	return fg | bg << 4;
}

// We want a 16 bit value to put to screen, with the top half being the background
// and foreground colours, and the bottom 8 bits being the character.
static uint16_t makeVGAEntry(char c, uint8_t colour) {
	uint16_t c16 = c;
	uint16_t colour16 = colour;
	return c16 | colour16 << 8;
}

// Initilise the terminal we're going to draw to.
void initTerminal() {
	terminal_row    = 0;
	terminal_column = 0;

	terminal_colour = makeColour(COLOUR_WHITE, COLOUR_BLACK);
	terminal_buffer = VIDEO_MEMORY;

	clearTerminal();
}

void clearTerminal() {
	for (unsigned int y = 0; y < VGA_HEIGHT; y++) {
		for (unsigned int x = 0; x < VGA_WIDTH; x++) {
			unsigned int index = getCharOffset(x, y);
			terminal_buffer[index] = makeVGAEntry(' ', terminal_colour);
		}
	}
}

unsigned int getCharOffset(unsigned int x, unsigned int y) {
	return y * VGA_WIDTH + x;
}

// Change the colour of the output from here on.
void terminalSetColour(uint8_t colour) {
	terminal_colour = colour;
}

// Move to a specific row and column before drawing the character.
void terminalMvPutC(char c, uint8_t colour, int col, int row) {
	const int index = row * VGA_WIDTH + col;
	terminal_buffer[index] = makeVGAEntry(c, colour);
}

// Put a charcter to the screen.
void terminalPutC(char c) {
	if (c == '\n') {
		terminal_column = 0;
		goto down_row;
	} else if (c == '\r') {
		terminal_column = 0;
		return;
	} else {
		terminalMvPutC(c, terminal_colour, terminal_column, terminal_row);
	}

	if (++terminal_column == VGA_WIDTH) {
		terminal_column = 0;
down_row:
		if (++terminal_row == VGA_HEIGHT)
			terminal_row = 0;
	}
}

// Put a string to the screen.
void terminalPutS(const char *str) {
	int len = strlen(str);
	for (int i = 0; i < len; i++)
		terminalPutC(str[i]);
}

// Set the cursor to the position given by offset number of characters
void ttySetCursor(unsigned short offset) {
	// Write the high byte of the offset
	outb(TTY_COMMAND_PORT, TTY_HIGH_BYTE_CMD);
	outb(TTY_DATA_PORT, (unsigned char) (offset & 0xff00));
	// Write the low byte of the offset
	outb(TTY_COMMAND_PORT, TTY_LOW_BYTE_CMD);
	outb(TTY_DATA_PORT, (unsigned char) (offset & 0x00ff));
}

// Gets the current position of the cursor in the terminal
unsigned short ttyGetCurosr() {
	unsigned short offset = 0;	// Initialise to 0
	// Write the high byte of the offset
	outb(TTY_COMMAND_PORT, TTY_HIGH_BYTE_CMD);
	offset = inb(TTY_DATA_PORT) << 8;
	// Write the low byte of the offset
	offset += inb(TTY_DATA_PORT);
	outb(TTY_COMMAND_PORT, TTY_LOW_BYTE_CMD);

	return offset;
}
