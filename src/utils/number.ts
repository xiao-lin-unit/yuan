
// 1. 定义单位常量（推荐写法）
export const UNIT = {
  HAO: { value: 1, radix: 5, precision: 0 },
  LI: { value: 10, radix: 4, precision: 0 },
  FEN: { value: 100, radix: 3, precision: 0 },
  JIAO: { value: 1000, radix: 2, precision: 0 },
  YUAN: { value: 10000, radix: 1, precision: 2 },
} as const;

// 2. 导出类型
export type UnitKey = keyof typeof UNIT;
export type UnitValue = (typeof UNIT)[UnitKey];


export const Amount = {

  format: (value: number, precision: number = 2): number => {
    return Number(Math.round(parseFloat(value + 'e' + precision)) + 'e-' + precision);
  },

  formatYuan: (value: number): number => {
    return Amount.format(value, 2);
  },

  yuan2Hao: (value: number): number => {
    return Math.round(value * 10000)
  },

  hao2Yuan: (value: number): number => {
    return Amount.format(Math.round(value / 10000), 4)
  },

  yuan2Fen: (value: number): number => {
    return Math.round(value * 100)
  },

  fen2Yuan: (value: number): number => {
    return Amount.format(Math.round(value / 100), 2)
  },


  plus: (...value: number[]): number => {
    let result = 0;
    value.forEach(v => {
      result += Amount.yuan2Hao(v);
    });
    return Amount.hao2Yuan(result);
  },

  minus: (minuend: number, ...subtrahends: number[]): number => {
    let result = Amount.yuan2Hao(minuend);
    subtrahends.forEach(v => {
      result -= Amount.yuan2Hao(v);
    });
    return Amount.hao2Yuan(result);
  },

  multiplyNum: (price: number, num: number): number => {
    let result = Amount.yuan2Hao(price);
    result *= num;
    return Amount.hao2Yuan(result);
  },

  dividePrice: (dividend: number, price: number): number => {
    let result = Amount.yuan2Hao(dividend) / Amount.yuan2Hao(price);
    return Amount.hao2Yuan(result);
  },

  divideNum: (dividend: number, num: number): number => {
    let result = Amount.yuan2Hao(dividend) / num;
    return Amount.hao2Yuan(result);
  },

  round: (value: number, precision: number = 2): number => {
    return Amount.format(value, precision)
  },

  ceil: (value: number, precision: number = 2): number => {
    return Number(Math.ceil(parseFloat(value + 'e' + precision)) + 'e-' + precision);
  },

  
}


export const Rate = {
  format: (value: number | string, precision: number = 2): string => {
    return Number(value).toFixed(precision)
  }
}


export const Percent = {
  format: (value: number | string, precision: number = 2): string => {
    return Number(value).toFixed(precision)
  }
}
