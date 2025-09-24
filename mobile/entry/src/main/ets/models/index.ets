// this page is for models specially used on Index page

class SelectModel {
  value: string
  icon: Resource

  constructor(value: string, icon: Resource) {
    this.value = value
    this.icon = icon
  }
}

export { SelectModel }