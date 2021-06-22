// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./Address.sol";
import "./EnumerableSet.sol";
import "./EnumerableMap.sol";

library OwnedRanges {
    using SafeMath for uint;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    struct OwnedRangesMapping {
        mapping (address => EnumerableSet.UintSet) _rangeStartHolders;
        mapping (uint => uint) _rangeStartsToEnds;
        EnumerableMap.UintToAddressMap _rangeStartReverseMapping;
        uint maxIndex;
        bool initialized;
        uint saturationPoint; }
    
    function init(OwnedRangesMapping storage rmap, address owner, uint number_of_items, uint saturationPoint) internal returns(bool) {
        require(!rmap.initialized);
        rmap._rangeStartHolders[owner].add(0);
        rmap._rangeStartsToEnds[0] = number_of_items;
        rmap._rangeStartReverseMapping.set(0, owner);
        rmap.maxIndex = number_of_items;
        rmap.initialized = true;
        rmap.saturationPoint = saturationPoint;
        return true; }
    
    function ownerOf(OwnedRangesMapping storage rmap, uint idx) internal view returns(address) {
        uint revMapLen = rmap._rangeStartReverseMapping.length();
        if (revMapLen > rmap.saturationPoint) {
            (bool hit, address owner) = rmap._rangeStartReverseMapping.tryGet(idx);
            if(hit) {
                return owner; } }
        uint currentEnd = rmap._rangeStartsToEnds[0];
        if (idx < currentEnd) {
            return rmap._rangeStartReverseMapping.get(0); }
        for (uint i = 0; i < revMapLen-1; i++) {
            uint currentStart = currentEnd;
            currentEnd = rmap._rangeStartsToEnds[currentStart];
            if (idx < currentEnd) {
                return rmap._rangeStartReverseMapping.get(currentStart); } }
        return address(0); }
    
    function _setOwner(OwnedRangesMapping storage rmap, uint idx, uint rangeStart, uint rangeEnd, address currentOwner, address newOwner) internal returns(bool) {
        uint nextRangeStart = idx+1;
        ///Handle when range len == 1
        if (nextRangeStart == rangeEnd) {
            //No range, simple transfer
            rmap._rangeStartHolders[currentOwner].remove(idx);
            rmap._rangeStartHolders[newOwner].add(idx);
            rmap._rangeStartReverseMapping.set(idx, newOwner);
            return true; }
        
        //Handle when range len > 1
        //We split the map into three, (start, n-idx), (idx) (idx+1, end)
        
        rmap._rangeStartsToEnds[rangeStart] = idx;
        rmap._rangeStartsToEnds[idx] = nextRangeStart;
        rmap._rangeStartsToEnds[nextRangeStart] = rangeEnd;
        rmap._rangeStartReverseMapping.set(idx, newOwner);
        rmap._rangeStartReverseMapping.set(nextRangeStart, currentOwner);
        rmap._rangeStartHolders[currentOwner].add(nextRangeStart);
        rmap._rangeStartHolders[newOwner].add(idx);
        return true; }
    
    function setOwner(OwnedRangesMapping storage rmap, uint idx, address newOwner) internal returns(bool) {
        uint revMapLen = rmap._rangeStartReverseMapping.length();
        if (revMapLen > rmap.saturationPoint) {
            (bool hit, address owner) = rmap._rangeStartReverseMapping.tryGet(idx);
            if(hit) {
                uint currentEnd = rmap._rangeStartsToEnds[idx];
                return _setOwner(rmap, idx, idx, currentEnd, owner, newOwner); } }
        address currentAddr = rmap._rangeStartReverseMapping.get(0);
        uint currentEnd = rmap._rangeStartsToEnds[0];
        if (idx < currentEnd) {
            return _setOwner(rmap, idx, 0, currentEnd, currentAddr, newOwner); }
        for (uint i = 0; i < revMapLen-1; i++) {
            uint currentStart = currentEnd;
            currentEnd = rmap._rangeStartsToEnds[currentStart];
            if (idx < currentEnd) {
                return _setOwner(rmap, idx, currentStart, currentEnd, rmap._rangeStartReverseMapping.get(currentStart), newOwner); } }
        return false; }
    
    function ownedIndexToIdx(OwnedRangesMapping storage rmap, address owner, uint ownedIndex) internal view returns(uint) {
        uint currentStart = rmap._rangeStartHolders[owner].at(0);
        uint currentEnd = rmap._rangeStartsToEnds[currentStart];
        if (ownedIndex < (currentEnd - currentStart)) {
            return currentStart + ownedIndex; }
        ownedIndex -= currentEnd - currentStart;
        if (ownedIndex < 1) {
            require(false); }
        for (uint i = 1; i < rmap._rangeStartHolders[owner].length(); i++) {
            currentStart = rmap._rangeStartHolders[owner].at(i);
            currentEnd = rmap._rangeStartsToEnds[currentStart];
            if (ownedIndex < (currentEnd - currentStart)) {
                return currentStart + ownedIndex; }
            ownedIndex -= currentEnd - currentStart;
            if (ownedIndex < 1) {
                require(false); } }
        require(false);
        return 0; }
    
    function ownerBalance(OwnedRangesMapping storage rmap, address owner) internal view returns(uint) {
        uint balance = 0;
        for (uint i = 0; i < rmap._rangeStartHolders[owner].length(); i++) {
            uint currentStart = rmap._rangeStartHolders[owner].at(i);
            uint currentEnd = rmap._rangeStartsToEnds[currentStart];
            balance += (currentEnd - currentStart); }
        return balance; }
    
    function length(OwnedRangesMapping storage rmap) internal view returns(uint) {
        return rmap.maxIndex; }
        
} 