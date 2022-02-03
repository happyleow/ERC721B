// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

/**
 * Updated, minimalist and gas efficient version of OpenZeppelins ERC721 contract.
 * Includes the Metadata and Enumerable extension.
 *
 * Assumes serials are sequentially minted starting at 0 (e.g. 0, 1, 2, 3..).
 * Does not support burning tokens
 *
 * @author beskay0x
 * Credits: chiru-labs, solmate, transmissions11, nftchance, squeebo_nft and others
 */

abstract contract ERC721B {
    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*///////////////////////////////////////////////////////////////
                          METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 tokenId) public view virtual returns (string memory);

    /*///////////////////////////////////////////////////////////////
                          ERC721 STORAGE
    //////////////////////////////////////////////////////////////*/

    // Array which maps token ID to address (index is tokenID)
    address[] internal _owners;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /*///////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x780e9d63 || // ERC165 Interface ID for ERC721Enumerable
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*///////////////////////////////////////////////////////////////
                       ERC721ENUMERABLE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _owners.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256 tokenId) {
        require(index < balanceOf(owner), 'ERC721Enumerable: owner index out of bounds');

        uint256 count;
        for (uint256 i; i < _owners.length; i++) {
            if (owner == ownerOf(i)) {
                if (count == index) return i;
                else count++;
            }
        }

        revert('ERC721Enumerable: owner index out of bounds');
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        require(index < _owners.length, 'ERC721Enumerable: global index out of bounds');
        return index;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Iterates through _owners array, returns balance of address
     * It is not recommended to call this function from another smart contract
     * as it can become quite expensive -- call this function off chain instead.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), 'ERC721: balance query for the zero address');

        uint256 count;
        for (uint256 i = 0; i < _owners.length; i++) {
            if (owner == ownerOf(i)) {
                unchecked {
                    count++;
                }
            }
        }
        return count;
    }

    /**
     * @dev See {IERC721-ownerOf}.
     * Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around in the collection over time.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        require(_exists(tokenId), 'ERC721: operator query for nonexistent token');

        for (uint256 i = tokenId; ; i++) {
            if (_owners[i] != address(0)) {
                return _owners[i];
            }
        }

        revert('ERC721A: unable to determine the owner of token');
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual {
        address owner = ownerOf(tokenId);
        require(to != owner, 'ERC721: approval to current owner');

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            'ERC721: approve caller is not owner nor approved for all'
        );

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        require(_exists(tokenId), 'ERC721: approved query for nonexistent token');

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        require(operator != msg.sender, 'ERC721: approve to caller');

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        require(_exists(tokenId), 'ERC721: operator query for nonexistent token');
        require(ownerOf(tokenId) == from, 'ERC721: transfer from incorrect owner');
        require(to != address(0), 'ERC721: transfer to the zero address');
        require(
            msg.sender == from || msg.sender == getApproved(tokenId) || isApprovedForAll(from, msg.sender),
            'ERC721: transfer caller is not owner nor approved'
        );

        // delete token approvals from previous owner
        delete _tokenApprovals[tokenId];
        _owners[tokenId] = to;

        // if token ID below transferred one isnt set, set it to previous owner
        // if tokenid is zero, skip this
        if (tokenId > 0) {
            if (_owners[tokenId - 1] == address(0)) {
                _owners[tokenId - 1] = from;
            }
        }

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(_checkOnERC721Received(from, to, id, ''), 'ERC721: transfer to non ERC721Receiver implementer');
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public virtual {
        transferFrom(from, to, id);

        require(_checkOnERC721Received(from, to, id, data), 'ERC721: transfer to non ERC721Receiver implementer');
    }

    /**
     * @dev Returns whether `tokenId` exists.
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return tokenId < _owners.length;
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert('ERC721: transfer to non ERC721Receiver implementer');
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev check if contract confirms token transfer, if not - reverts
     * unlike the standard ERC721 implementation this is only called once per mint,
     * no matter how many tokens get minted, since it is useless to check this
     * requirement several times -- if the contract confirms one token,
     * it will confirm all additional ones too.
     * This saves us around 5k gas per additional mint
     */
    function _safeMint(address to, uint256 qty) internal virtual {
        _mint(to, qty);

        require(
            _checkOnERC721Received(address(0), to, _owners.length - 1, ''),
            'ERC721: transfer to non ERC721Receiver implementer'
        );
    }

    function _safeMint(
        address to,
        uint256 qty,
        bytes memory data
    ) internal virtual {
        _mint(to, qty);

        require(
            _checkOnERC721Received(address(0), to, _owners.length - 1, data),
            'ERC721: transfer to non ERC721Receiver implementer'
        );
    }

    function _mint(address to, uint256 qty) internal virtual {
        require(to != address(0), 'ERC721: mint to the zero address');
        require(qty > 0, 'ERC721: quantity must be greater than 0');

        uint256 _currentIndex = _owners.length;

        for (uint256 i = 0; i < qty - 1; i++) {
            _owners.push();
            emit Transfer(address(0), to, _currentIndex + i);
        }

        // set last index to receiver
        _owners.push(to);
        emit Transfer(address(0), to, _currentIndex + (qty - 1));
    }
}
