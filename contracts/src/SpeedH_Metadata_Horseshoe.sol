// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { SpeedH_Stats_Horseshoe } from "./SpeedH_Stats_Horseshoe.sol";

contract SpeedH_Metadata_Horseshoe {
    using Strings for uint256;

    string public version = "SpeedH_Metadata_Horseshoe-v1.0.0";

    function tokenURI(
        uint256 horseshoeId,
        SpeedH_Stats_Horseshoe.HorseshoeData calldata data,
        string memory categoryName
    ) external pure returns (string memory) {
        string memory attributes = '[';
        bool isFirst = true;

        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Power", data.bonusStats.power, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Acceleration", data.bonusStats.acceleration, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Stamina", data.bonusStats.stamina, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Min Speed", data.bonusStats.minSpeed, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Max Speed", data.bonusStats.maxSpeed, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Luck", data.bonusStats.luck, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Curve Bonus", data.bonusStats.curveBonus, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Straight Bonus", data.bonusStats.straightBonus, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Durability", data.durabilityRemaining, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Max Durability", data.maxDurability, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Level", data.level, isFirst);

        string memory pureValue = data.isPure ? "Yes" : "No";
        string memory pureEntry = string(abi.encodePacked('{"trait_type":"Pure","value":"', pureValue, '"}'));
        string memory separator = isFirst ? "" : ",";
        attributes = string(abi.encodePacked(attributes, separator, pureEntry));
        attributes = string(abi.encodePacked(attributes, ']'));

        string memory categoryPath = _categoryPathSegment(categoryName, data.imgCategory);

        string memory json = string(
            abi.encodePacked(
                '{',
                '"name":"Horseshoe #', horseshoeId.toString(), '",',
                '"description":"A horseshoe that can be equipped to a Speed Horse to enhance its performance.",',
                '"image":"ipfs://category/', categoryPath, '/', data.imgNumber.toString(), '",',
                '"attributes":', attributes,
                '}'
            )
        );

        return string(abi.encodePacked("data:application/json;utf8,", json));
    }

    function _attributeJson(string memory trait, uint256 value) private pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', trait, '","value":', value.toString(), '}'));
    }

    function _appendAttributeIfNonZero(
        string memory current,
        string memory trait,
        uint256 value,
        bool isFirst
    ) private pure returns (string memory, bool) {
        if (value == 0) {
            return (current, isFirst);
        }

        string memory separator = isFirst ? "" : ",";
        string memory updated = string(abi.encodePacked(current, separator, _attributeJson(trait, value)));
        return (updated, false);
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
}
