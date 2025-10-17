// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_Stats_Horse } from "./SpeedH_Stats_Horse.sol";
import { UFix6, SpeedH_UFix6Lib } from "./SpeedH_UFix6Lib.sol";

contract SpeedH_Metadata_Horse {
    using Strings for uint256;

    function tokenURI(
        uint256 horseId,
        SpeedH_Stats_Horse.HorseData calldata data,
        PerformanceStats calldata totalStats,
        UFix6 level,
        string memory categoryName
    ) external pure returns (string memory) {
        string memory attributes = string(
            abi.encodePacked(
                '[',
                _attributeJson("Power", totalStats.power), ',',
                _attributeJson("Acceleration", totalStats.acceleration), ',',
                _attributeJson("Stamina", totalStats.stamina), ',',
                _attributeJson("Min Speed", totalStats.minSpeed), ',',
                _attributeJson("Max Speed", totalStats.maxSpeed), ',',
                _attributeJson("Luck", totalStats.luck), ',',
                _attributeJson("Curve Bonus", totalStats.curveBonus), ',',
                _attributeJson("Straight Bonus", totalStats.straightBonus),
                ']'
            )
        );

        string memory categoryPath = _categoryPathSegment(categoryName, data.imgCategory);

        string memory json = string(
            abi.encodePacked(
                '{',
                '"name":"Speed Horse #', horseId.toString(), '",',
                '"description":"Composite statistics between the horse and its equipped horseshoes.",',
                '"image":"ipfs://category/', categoryPath, '/', data.imgNumber.toString(), '",',
                '"level":"', _ufix6ToString(level), '",',
                '"totalPoints":', data.totalPoints.toString(), ',',
                '"attributes":', attributes,
                '}'
            )
        );

        return string(abi.encodePacked("data:application/json;utf8,", json));
    }

    function _attributeJson(string memory trait, uint256 value) private pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', trait, '","value":', value.toString(), '}'));
    }

    function _categoryPathSegment(string memory categoryName, uint256 fallbackId)
        private
        pure
        returns (string memory)
    {
        if (bytes(categoryName).length > 0) {
            return categoryName;
        }
        return fallbackId.toString();
    }

    function _ufix6ToString(UFix6 value) private pure returns (string memory) {
        uint256 rawValue = SpeedH_UFix6Lib.raw(value);
        uint256 integerPart = rawValue / 1e6;
        uint256 fractionalPart = rawValue % 1e6;

        if (fractionalPart == 0) {
            return integerPart.toString();
        }

        bytes memory fractionalBuffer = new bytes(6);
        for (uint256 i = 0; i < 6; i++) {
            uint256 digit = fractionalPart % 10;
            fractionalBuffer[5 - i] = bytes1(uint8(48 + digit));
            fractionalPart /= 10;
        }

        uint256 length = 6;
        while (length > 0 && fractionalBuffer[length - 1] == bytes1("0")) {
            length--;
        }

        bytes memory trimmed = new bytes(length);
        for (uint256 j = 0; j < length; j++) {
            trimmed[j] = fractionalBuffer[j];
        }

        return string(abi.encodePacked(integerPart.toString(), ".", string(trimmed)));
    }
}
