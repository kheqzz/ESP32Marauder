//                            USER DEFINED SETTINGS
//   TFT_eSPI setup for Marauder Pancake (ESP32-C5-DevKitC-1 + ILI9341 3.5")

// ##################################################################################
// Section 1. Driver
// ##################################################################################

//#define ILI9341_DRIVER
#define ST7796_DRIVER

// 3.5-inch portrait panel native resolution
#define TFT_WIDTH  320
#define TFT_HEIGHT 480


// If colours are inverted (white shows as black) then uncomment one of the next
// 2 lines try both options, one of the options should correct the inversion.

#define TFT_INVERSION_ON
// #define TFT_INVERSION_OFF

// ##################################################################################
// Section 2. Pin assignments (Pancake hardware)
// ##################################################################################

#define TFT_MISO  25   // unused by this panel, but TFT_eSPI needs a real pin to init the bus
                       // (must stay a valid free GPIO; GPIO15 crashes, -1 blanks the panel)
#define TFT_MOSI  8
#define TFT_SCLK  10
#define TFT_CS    5    // TFT chip select
#define TFT_DC    0    // Data/command
#define TFT_RST   1    // Reset
#define TFT_BL    26   // Backlight

#define TOUCH_CS  -1   // No resistive touch chip; FT6336 is I2C-only

// ##################################################################################
// Section 3. Fonts
// ##################################################################################

#define LOAD_GLCD
#define LOAD_FONT2
#define LOAD_FONT4
// #define LOAD_FONT6
// #define LOAD_FONT7
// #define LOAD_FONT8
#define LOAD_GFXFF
#define SMOOTH_FONT

// ##################################################################################
// Section 4. SPI speed
// ##################################################################################

#define SPI_FREQUENCY       27000000
#define SPI_READ_FREQUENCY  20000000
#define SPI_TOUCH_FREQUENCY  2500000
