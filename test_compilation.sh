#!/bin/bash
cd C:/Projects/life-logger/zuralog/android
./gradlew :app:compileDebugKotlin 2>&1 | grep -i error
