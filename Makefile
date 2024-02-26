CXX = g++
SRC_DIR = src
INC_DIR = include
CXXFLAGS = -Wall -Wextra -I$(INC_DIR) -std=c++17 -O3
LDFLAGS = -luring
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = $(BUILD_DIR)/bin
MAIN = main.cpp
SOURCES = $(wildcard $(SRC_DIR)/*.cpp)
OBJECTS = $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SOURCES))

all: directories $(BIN_DIR)/benchmark

$(BIN_DIR)/benchmark: $(OBJ_DIR)/main.o $(OBJECTS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJ_DIR)/main.o: $(MAIN) 
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(OBJECTS): $(SOURCES)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

directories:
	mkdir -p $(OBJ_DIR)
	mkdir -p $(BIN_DIR)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)