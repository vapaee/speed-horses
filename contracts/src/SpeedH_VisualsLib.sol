// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SpeedH_VisualsLib
/// @notice Reusable storage & helpers to manage image categories and random visual selection.
library SpeedH_VisualsLib {
    error NoCategories();
    error CategoriesEmpty();
    error InvalidSelection();

    struct ImgCategoryData {
        string name;
        uint256 maxImgNumber;
        bool exists;
    }

    struct VisualSpace {
        // categoryId => data
        mapping(uint256 => ImgCategoryData) imgCategories;
        // list of category ids to iterate/select from
        uint256[] imgCategoryIds;
    }

    /// @dev Adds or updates a category inside a given VisualSpace.
    function setImgCategory(
        VisualSpace storage vs,
        uint256 imgCategory,
        string calldata name,
        uint256 maxImgNumber
    ) internal {
        ImgCategoryData storage data = vs.imgCategories[imgCategory];

        if (!data.exists) {
            vs.imgCategoryIds.push(imgCategory);
            data.exists = true;
        }

        data.name = name;
        data.maxImgNumber = maxImgNumber;
    }

    /// @dev Returns a copy of category ids for off-chain consumption.
    function getImgCategoryIds(VisualSpace storage vs) internal view returns (uint256[] memory) {
        uint256 len = vs.imgCategoryIds.length;
        uint256[] memory out = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = vs.imgCategoryIds[i];
        }
        return out;
    }

    /// @dev Picks a random (category, number) within non-empty categories of this VisualSpace.
    ///      Selection algorithm mirrors previous behavior.
    function getRandomVisual(
        VisualSpace storage vs,
        uint256 entropy
    ) internal view returns (uint256 imgCategory, uint256 imgNumber) {
        if (vs.imgCategoryIds.length == 0) revert NoCategories();

        uint256 validCategories = 0;
        uint256 length = vs.imgCategoryIds.length;
        for (uint256 i = 0; i < length; i++) {
            ImgCategoryData storage data = vs.imgCategories[vs.imgCategoryIds[i]];
            if (data.exists && data.maxImgNumber > 0) {
                validCategories++;
            }
        }
        if (validCategories == 0) revert CategoriesEmpty();

        uint256 categorySeed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, entropy))
        );
        uint256 categoryIndex = categorySeed % validCategories;

        uint256 selectedCategory = type(uint256).max;
        uint256 counter;
        for (uint256 i = 0; i < length; i++) {
            ImgCategoryData storage data = vs.imgCategories[vs.imgCategoryIds[i]];
            if (data.exists && data.maxImgNumber > 0) {
                if (counter == categoryIndex) {
                    selectedCategory = vs.imgCategoryIds[i];
                    break;
                }
                counter++;
            }
        }
        if (selectedCategory == type(uint256).max) revert InvalidSelection();

        ImgCategoryData storage chosen = vs.imgCategories[selectedCategory];
        uint256 numberSeed = uint256(keccak256(abi.encodePacked(categorySeed, entropy, block.number)));
        uint256 selectedNumber = (numberSeed % chosen.maxImgNumber) + 1;

        return (selectedCategory, selectedNumber);
    }
}
