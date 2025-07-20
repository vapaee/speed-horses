// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --------------------------------------------------------------------------
// This file contains placeholder values for common constants used across
// contracts. Real values should be provided in the final system.
// --------------------------------------------------------------------------

uint256 constant MIN_SPEED_BASE_VALUE        = 1 ether;
uint256 constant LUCK_ENUM                   = 1;
uint256 constant LUCK_SPEED_PER_LEVEL        = 1 ether;
uint256 constant LUCK_MIN_POINTS             = 1;
uint256 constant CURVE_ENUM                  = 2;
uint256 constant CURVE_SPEED_PER_LEVEL       = 1 ether;
uint256 constant CURVE_MIN_POINTS            = 1;
uint256 constant STRAIGHT_ENUM               = 3;
uint256 constant STRAIGHT_SPEED_PER_LEVEL    = 1 ether;
uint256 constant STRAIGHT_MIN_POINTS         = 1;
uint256 constant MAX_SPEED_EXTRA_POINTS      = 1;
uint256 constant MAX_SPEED_ADVANCE_PER_LEVEL = 1 ether;
uint256 constant TOTAL_RACE_ITERATIONS       = 20;
uint256 constant STAMINA_METERS_PER_LEVEL    = 1 ether;
uint256 constant MIN_DISTANCE_RESISTANCE     = 1 ether;
uint256 constant MAX_ACCELERATION            = 8;
uint256 constant MIN_ACCELERATION            = 2;
uint256 constant TOTAL_ACCELERATION          = MAX_ACCELERATION + MIN_ACCELERATION;
uint256 constant PRICE_PER_POINT             = 1 ether;
uint256 constant BASE_RACE_COOLDOWN          = 1 days;
uint256 constant BASE_FEED_COOLDOWN          = 1 days;

// ---------------------- RaceManager ----------------------
uint256 constant MAX_SEED_QUEUE_LENGTH                = 16;
uint256 constant SEED_TIME_THRESHOLD                  = 5 minutes;
uint256 constant SEED_HASH_THRESHOLD                  = 0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant SEED_CHAIN_LENGTH                    = 4;

uint256 constant MAX_FIXTURE_HORSES                   = 64;
uint256 constant MAX_POINTS_DIFFERENCE_TOLERANCE      = 5;
uint256 constant MAX_LEVELS_DIFFERENCE_TOLERANCE      = 2;
uint256 constant FIXTURE_MIN_TIME_DISTANCE            = 1 hours;
uint256 constant FIXTURE_MAX_TIME_DISTANCE            = 24 hours;
uint256 constant FIXTURE_CONFIRM_TIME                 = 30 minutes;
uint256 constant TIME_BETWEEN_RACES                   = 5 minutes;

uint256 constant MIN_HORSES_PER_RACE                  = 2;
uint256 constant MAX_HORSES_PER_RACE                  = 8;
uint256 constant TOTAL_TRACK_LENGTH                   = 1000;
uint256 constant MAX_HORSE_LEVEL_TRACK_MODIFIER       = 10;

uint256 constant RACE_HORSE_INSCRIPTION_COST_PER_LEVEL = 1 ether;
uint256 constant HORSE_NOT_CHOSEN_CONSOLATION_PRICE_MULTIPLIER = 1;
uint256 constant RACE_TOTAL_PRICE_BASE                = 1 ether;
