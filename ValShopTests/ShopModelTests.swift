import XCTest
@testable import ValShop

final class ShopModelTests: XCTestCase {
    func testCredentialRequiresBothValues() {
        XCTAssertFalse(ShopCredential(userId: "", tid: "x", nickname: nil, openID: nil, uin: nil).isComplete)
        XCTAssertFalse(ShopCredential(userId: "x", tid: "", nickname: nil, openID: nil, uin: nil).isComplete)
        XCTAssertTrue(ShopCredential(userId: "x", tid: "y", nickname: nil, openID: nil, uin: nil).isComplete)
    }

    func testItemFallbacks() {
        let item = ShopItem(dictionary: ["goods_name": "幻影", "rmb_price": 1290], index: 2)
        XCTAssertEqual(item.name, "幻影")
        XCTAssertEqual(item.price, "1290")
        XCTAssertEqual(item.id, "item-2")
    }
}
