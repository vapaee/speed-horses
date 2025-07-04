// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --------------------------------------------------------------------------
// This file contains placeholder values for common constants used across
// contracts. Real values should be provided in the final system.
// --------------------------------------------------------------------------

uint256 constant MIN_SPEED_BASE_VALUE       = 1 ether;
uint256 constant LUCK_ENUM                 = 1;
uint256 constant LUCK_SPEED_PER_LEVEL      = 1 ether;
uint256 constant LUCK_MIN_POINTS           = 1;
uint256 constant CURVE_ENUM                = 2;
uint256 constant CURVE_SPEED_PER_LEVEL     = 1 ether;
uint256 constant CURVE_MIN_POINTS          = 1;
uint256 constant STRAIGHT_ENUM             = 3;
uint256 constant STRAIGHT_SPEED_PER_LEVEL  = 1 ether;
uint256 constant STRAIGHT_MIN_POINTS       = 1;
uint256 constant MAX_SPEED_EXTRA_POINTS    = 1;
uint256 constant MAX_SPEED_ADVANCE_PER_LEVEL = 1 ether;
uint256 constant TOTAL_RACE_ITERATIONS     = 20;
uint256 constant STAMINA_METERS_PER_LEVEL  = 1 ether;
uint256 constant MIN_DISTANCE_RESISTANCE   = 1 ether;
uint256 constant MAX_ACCELERATION          = 8;
uint256 constant MIN_ACCELERATION          = 2;
uint256 constant TOTAL_ACCELERATION        = MAX_ACCELERATION + MIN_ACCELERATION;
uint256 constant PRICE_PER_POINT           = 1 ether;
uint256 constant BASE_RACE_COOLDOWN        = 1 days;
uint256 constant BASE_FEED_COOLDOWN        = 1 days;
