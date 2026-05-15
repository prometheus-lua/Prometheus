export function toLuaLongString(value: string): string {
  let equals = ""
  while (value.includes(`]${equals}]`)) {
    equals += "="
  }
  return `[${equals}[${value}]${equals}]`
}
