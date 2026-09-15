cmake_minimum_required(VERSION 3.22.1)
project("xydesk_native")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(xydesk_control SHARED xydesk_control.cpp)
add_library(xydesk_audio SHARED xydesk_audio.cpp)
add_library(xydesk_streamer SHARED xydesk_streamer.cpp)
add_library(xydesk_bridge SHARED native_bridge.cpp)

target_include_directories(xydesk_control PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_include_directories(xydesk_audio PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_include_directories(xydesk_streamer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_include_directories(xydesk_bridge PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

find_library(log-lib log)

target_link_libraries(xydesk_bridge
    PRIVATE
    xydesk_control
    xydesk_audio
    xydesk_streamer
    ${log-lib}
)
