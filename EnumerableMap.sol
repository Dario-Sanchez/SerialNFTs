// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library EnumerableMap {

    struct MapEntry {
        bytes32 _key;
        bytes32 _value; }

    struct Map {
        MapEntry[] _entries;
        mapping (bytes32 => uint) _indexes; }

    function _set(Map storage map, bytes32 key, bytes32 value) private returns(bool) {
        uint keyIndex = map._indexes[key];
        if (keyIndex == 0) {
            map._entries.push(MapEntry({ _key: key, _value: value }));
            map._indexes[key] = map._entries.length;
            return true; } 
        else {
            map._entries[keyIndex - 1]._value = value;
            return false; } }

    function _remove(Map storage map, bytes32 key) private returns(bool) {
        uint keyIndex = map._indexes[key];

        if (keyIndex != 0) { 
            uint toDeleteIndex = keyIndex - 1;
            uint lastIndex = map._entries.length - 1;
            MapEntry storage lastEntry = map._entries[lastIndex];
            map._entries[toDeleteIndex] = lastEntry;
            map._indexes[lastEntry._key] = toDeleteIndex + 1; 
            map._entries.pop();
            delete map._indexes[key];
            return true;
        } else {
            return false; } }

    function _contains(Map storage map, bytes32 key) private view returns(bool) {
        return map._indexes[key] != 0; }

    function _length(Map storage map) private view returns(uint) {
        return map._entries.length; }

    function _at(Map storage map, uint index) private view returns(bytes32, bytes32) {
        require(map._entries.length > index, "EnumerableMap: index out of bounds");
        MapEntry storage entry = map._entries[index];
        return (entry._key, entry._value); }

    function _tryGet(Map storage map, bytes32 key) private view returns(bool, bytes32) {
        uint keyIndex = map._indexes[key];
        if (keyIndex == 0) return (false, 0); 
        return (true, map._entries[keyIndex - 1]._value); }

    function _get(Map storage map, bytes32 key) private view returns(bytes32) {
        uint keyIndex = map._indexes[key];
        require(keyIndex != 0, "EnumerableMap: nonexistent key"); 
        return map._entries[keyIndex - 1]._value; }

    function _get(Map storage map, bytes32 key, string memory errorMessage) private view returns(bytes32) {
        uint keyIndex = map._indexes[key];
        require(keyIndex != 0, errorMessage); 
        return map._entries[keyIndex - 1]._value; }

    struct UintToAddressMap {
        Map _inner; }

    function set(UintToAddressMap storage map, uint key, address value) internal returns(bool) {
        return _set(map._inner, bytes32(key), bytes32(uint(uint160(value)))); }

    function remove(UintToAddressMap storage map, uint key) internal returns(bool) {
        return _remove(map._inner, bytes32(key)); }

    function contains(UintToAddressMap storage map, uint key) internal view returns(bool) {
        return _contains(map._inner, bytes32(key)); }

    function length(UintToAddressMap storage map) internal view returns(uint) {
        return _length(map._inner); }

    function at(UintToAddressMap storage map, uint index) internal view returns(uint, address) {
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (uint(key), address(uint160(uint(value)))); }

    function tryGet(UintToAddressMap storage map, uint key) internal view returns(bool, address) {
        (bool success, bytes32 value) = _tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint(value)))); }

    function get(UintToAddressMap storage map, uint key) internal view returns(address) {
        return address(uint160(uint(_get(map._inner, bytes32(key))))); }

    function get(UintToAddressMap storage map, uint key, string memory errorMessage) internal view returns(address) {
        return address(uint160(uint(_get(map._inner, bytes32(key), errorMessage)))); }
}