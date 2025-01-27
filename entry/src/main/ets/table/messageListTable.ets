// import Constants from '../../constants/constant'
// import { MessageItem, MessageItem } from '../models/database';
// import RDBUtil from '../utils/rdbUtils'
// import relationalStore from '@ohos.data.relationalStore';
//
// class MessageListItemTable {
//   private table = new RDBUtil('MessageListTable', Constants.CREATE_MESSAGE_LIST_TABLE_SQL, ['messages', 'topic'])
//
//   constructor(callback: Function = () => {
//   }) {
//     this.table.getRdbStore(callback);
//   }
//
//   getRdbStore(callback: Function = () => {
//   }) {
//     this.table.getRdbStore(callback);
//   }
//
//   insertItem(item: MessageItem, callback: Function) {
//     let value: relationalStore.ValuesBucket = generateBuket(item);
//     this.table.insertData(value, callback);
//   }
//
//   deleteItem(item: MessageItem, callback: Function) {
//     let predicatesDel = new relationalStore.RdbPredicates(Constants.SHOPPING_LIST_TABLE_NAME);
//     predicatesDel.equalTo('ID', item.category + item.name);
//     this.table.deleteData(predicatesDel, callback);
//   }
//
//   deleteAll(callback: Function) {
//     let predicatesDelAll = new relationalStore.RdbPredicates(Constants.SHOPPING_LIST_TABLE_NAME);
//     this.table.deleteData(predicatesDelAll, callback);
//   }
//
//   updateItem(item: MessageItem, callback: Function) {
//     let value: relationalStore.ValuesBucket = generateBuket(item);
//     let predicatesUpdate = new relationalStore.RdbPredicates(Constants.SHOPPING_LIST_TABLE_NAME);
//     predicatesUpdate.equalTo('ID', item.category + item.name);
//     this.table.updateData(value, predicatesUpdate, callback);
//   }
//
//   queryItemsByCategory(category: string, callback: Function) {
//     let predicatesUpdate = new relationalStore.RdbPredicates(Constants.SHOPPING_LIST_TABLE_NAME);
//     predicatesUpdate.equalTo('CATEGORY', category);
//
//     this.table.queryData(predicatesUpdate, (resultSet: relationalStore.ResultSet) => {
//       let itemList: MessageItem[] = [];
//       if ((resultSet != undefined) && (resultSet.rowCount > 0)) {
//         while (resultSet.goToNextRow()) {
//           let name: string = resultSet.getString(resultSet.getColumnIndex('NAME'));
//           let quantity: number = resultSet.getLong(resultSet.getColumnIndex('QUANTITY'));
//           let done: number = resultSet.getLong(resultSet.getColumnIndex('DONE'));
//           let category: string = resultSet.getString(resultSet.getColumnIndex('CATEGORY'));
//           itemList.push(new MessageItem(name, quantity, Boolean(done), category));
//         }
//         resultSet.close();
//       }
//       callback(itemList)
//     });
//   }
// }
//
// function generateBuket(item: MessageItem): relationalStore.ValuesBucket {
//   let value: relationalStore.ValuesBucket = {
//     MESSAGES: item.messages,
//     TOPIC: item.topic
//   };
//   return value;
// }