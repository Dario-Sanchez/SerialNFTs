// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721.sol";
import "./OwnedRanges.sol";

interface IERC2309 {
    event ConsecutiveTransfer(uint indexed fromTokenId, uint toTokenId, address indexed fromAddress, address indexed toAddress);
    event TransferForLots(uint fromTokenId, uint toTokenId, address indexed fromAddress, address indexed toAddress);
}

    /*
    function _init(address to, uint number_of_tokens) internal virtual {
        owners.init(to, number_of_tokens, number_of_tokens / 3);
        emit ConsecutiveTransfer(0, number_of_tokens, address(0), to);
    }
    

    function _transferFotLots(address to, uint fromTokenId, uint toTokenId) internal virtual {
        owners.init(to, number_of_tokens, number_of_tokens / 3);
        emit TransferForLots(fromTokenId, toTokenId, msg.sender, to);
    }
    */

contract NFTsERC2309 is Context, ERC165, IERC721, IERC721Metadata, IERC721Enumerable, IERC2309 {
    using SafeMath for uint;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint;
    using OwnedRanges for OwnedRanges.OwnedRangesMapping;

    // Equals to `bytes4(keccak("onERC721Received(address,address,uint,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    
    OwnedRanges.OwnedRangesMapping private owners;
    
    // Mapping from token ID to approved address
    mapping (uint => address) private _tokenApprovals;
    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;
    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;
    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;
    // Optional mapping for token URIs
    mapping (uint => string) private _tokenURIs;

    string private _name;
    string private _symbol;
    // Base URI
    string private _baseURI;

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;
    
    address public contractOwner;
    
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "require is not owner");
        _;
    }

    //        **************************************
    //        ************ CONSTRUCTOR *************
    //        **************************************
    
    constructor (string memory name_, string memory symbol_, uint cant, string memory baseURI_) {
        _name = name_;
        _symbol = symbol_;
        contractOwner = msg.sender;

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
        
        _init(msg.sender, cant);
        _setBaseURI(baseURI_);
    }


    //IERC721-balanceOf
    function balanceOf(address owner) public view virtual override returns(uint) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return owners.ownerBalance(owner);
    }

    //IERC721-ownerOf
    function ownerOf(uint tokenId) public view virtual override returns(address) {
        //(bool success, bytes32 value) = _tokenOwners.tryGet(tokenId)
        //return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
        return owners.ownerOf(tokenId);
    }

    //IERC721Metadata-name
    function name() public view virtual override returns(string memory) {
        return _name;
    }

    //IERC721Metadata-symbol
    function symbol() public view virtual override returns(string memory) {
        return _symbol;
    }

    //IERC721Metadata-tokenURI
    function tokenURI(uint tokenId) public view virtual override returns(string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    //returnsthe base URI set via {_setBaseURI}. This will be automatically added as a prefix in {tokenURI} to each token's URI
    function baseURI() public view virtual returns(string memory) {
        return _baseURI;
    }
    
    /*returnsthe base URI set via {_setBaseURI}. This will be automatically added as a prefix in {tokenURI} to each token's URI
    function setbaseURI(string memory baseURI) public virtual returns(string bool) {
        return true;
    }
    */

    //IERC721Enumerable-tokenOfOwnerByIndex
    function tokenOfOwnerByIndex(address owner, uint index) public view virtual override returns(uint) {
        return owners.ownedIndexToIdx(owner, index);
    }

    //IERC721Enumerable-totalSupply
    function totalSupply() public view virtual override returns(uint) {
        // _tokenOwners are indexed by tokenIds, so .length() returnsthe number of tokenIds
        return owners.length();
    }

    //IERC721Enumerable-tokenByIndex
    function tokenByIndex(uint index) public view virtual override returns(uint) {
        return index;
    }

    //IERC721-approve
    function approve(address to, uint tokenId) public virtual override {
        address owner = NFTsERC2309.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || NFTsERC2309.isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    //IERC721-getApproved
    function getApproved(uint tokenId) public view virtual override returns(address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    //IERC721-setApprovalForAll
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    //IERC721-isApprovedForAll
    function isApprovedForAll(address owner, address operator) public view virtual override returns(bool) {
        //return _operatorApprovals[owner][operator];
        require(!_operatorApprovals[owner][operator]);
        return true;
    }

    //IERC721-transferFrom
    function transferFrom(address from, address to, uint tokenId) public virtual onlyOwner override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    //IERC721-safeTransferFrom
    function safeTransferFrom(address from, address to, uint tokenId) public virtual onlyOwner override {
        safeTransferFrom(from, to, tokenId, "");
    }

    //IERC721-safeTransferFrom
    function safeTransferFrom(address from, address to, uint tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    //Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
    //`_data` is additional data, it has no specified format and it is sent in call to `to`.
    function _safeTransfer(address from, address to, uint tokenId, bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    //returnswhether `tokenId` exists.
    //Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
    function _exists(uint tokenId) internal view virtual returns(bool) {
        return owners.length() > tokenId;
    }

    //returnswhether `spender` is allowed to manage `tokenId`.
    function _isApprovedOrOwner(address spender, uint tokenId) internal view virtual returns(bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = NFTsERC2309.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || NFTsERC2309.isApprovedForAll(owner, spender));
    }

    //Safely mints `tokenId` and transfers it to `to`.
    function _safeMint(address to, uint tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    //Same as ERC721-_safeMint-address-uint-}[`_safeMint`] with an additional `data` parameter which is
    function _safeMint(address to, uint tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    //Mints `tokenId` and transfers it to `to`, but usage of this method is discouraged, use {_safeMint} whenever possible
    function _mint(address to, uint tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        _beforeTokenTransfer(address(0), to, tokenId);
        _holderTokens[to].add(tokenId);
        _tokenOwners.set(tokenId, to);
        emit Transfer(address(0), to, tokenId);
    }
    

    // Burn `tokenId`.
    function _burn(uint tokenId) internal virtual {
        address owner = ownerOf(tokenId); // internal owner
        _beforeTokenTransfer(owner, address(0), tokenId);
        // Clear approvals
        _approve(address(0), tokenId);
        // Clear metadata (if any)
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
        _holderTokens[owner].remove(tokenId);
        _tokenOwners.remove(tokenId);
        emit Transfer(owner, address(0), tokenId);
    }

    //Transfers `tokenId` from `from` to `to`.
    //As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
    function _transfer(address from, address to, uint tokenId) internal virtual {
        require(NFTsERC2309.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own"); // internal owner
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        owners.setOwner(tokenId, to);

        emit Transfer(from, to, tokenId);
    }

    //Sets `_tokenURI` as the tokenURI of `tokenId`.
    function _setTokenURI(uint tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    //Internal function to set the base URI for all token IDs
    function _setBaseURI(string memory baseURI_) internal virtual {
        _baseURI = baseURI_ ;
    }

    //Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
    function _checkOnERC721Received(address from, address to, uint tokenId, bytes memory _data)
        private returns(bool)
    {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
            IERC721Receiver(to).onERC721Received.selector,
            _msgSender(),
            from,
            tokenId,
            _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    function _approve(address to, uint tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(NFTsERC2309.ownerOf(tokenId), to, tokenId); // internal owner
    }

    //Hook that is called before any token transfer. This includes minting and burning.
    function _beforeTokenTransfer(address from, address to, uint tokenId) internal virtual { }
    
    function _init(address to, uint number_of_tokens) internal virtual {
        owners.init(to, number_of_tokens, number_of_tokens / 3);
        emit ConsecutiveTransfer(0, number_of_tokens, address(0), to);
    }
    
    /*
    function _transferFotLots(address to, uint number_of_tokens) internal virtual {
        owners.init(to, number_of_tokens, number_of_tokens / 3);
        emit ConsecutiveTransfer(0, number_of_tokens, address(0), to);
    }
    */
    
}