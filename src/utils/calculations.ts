/**
 * Shared calculation utilities
 */

/**
 * Round a number to specified decimal places
 */
export function roundToDecimals(value: number, decimals: number): number {
  const factor = Math.pow(10, decimals)
  return Math.round(value * factor) / factor
}

/**
 * Calculate total cost including fee
 * totalCost = (price * quantity) + fee
 */
export function calculateTotalCost(price: number, quantity: number, fee: number): number {
  return (price * quantity) + fee
}

/**
 * Calculate net proceeds after fee deduction
 * netProceeds = (price * quantity) - fee
 */
export function calculateNetProceeds(price: number, quantity: number, fee: number): number {
  return (price * quantity) - fee
}

/**
 * Calculate cost price per unit including fee
 * costPrice = ((price * quantity) + fee) / quantity
 */
export function calculateCostPrice(price: number, quantity: number, fee: number): number {
  if (quantity === 0) return 0
  return ((price * quantity) + fee) / quantity
}

/**
 * Calculate weighted average cost price for additional purchases
 * newCostPrice = ((heldCost * heldQty) + (newPrice * newQty) + fee) / (heldQty + newQty)
 */
export function calculateWeightedCostPrice(
  heldCost: number,
  heldQty: number,
  newPrice: number,
  newQty: number,
  fee: number
): number {
  const totalQty = heldQty + newQty
  if (totalQty === 0) return 0
  const totalCost = (heldCost * heldQty) + (newPrice * newQty) + fee
  return totalCost / totalQty
}

/**
 * Calculate profit/loss from selling
 * profit = (sellPrice - costPrice) * quantity - fee
 */
export function calculateSellProfit(
  sellPrice: number,
  costPrice: number,
  quantity: number,
  fee: number
): number {
  return (sellPrice - costPrice) * quantity - fee
}

/**
 * Calculate fund NAV cost price
 * navCostPrice = ((nav * shares) + fee) / shares
 */
export function calculateFundNavCostPrice(nav: number, shares: number, fee: number): number {
  if (shares === 0) return 0
  return ((nav * shares) + fee) / shares
}

/**
 * Calculate fund weighted NAV cost price
 * newNavCostPrice = ((heldNav * heldShares) + (newNav * newShares) + fee) / (heldShares + newShares)
 */
export function calculateFundWeightedNavCostPrice(
  heldNav: number,
  heldShares: number,
  newNav: number,
  newShares: number,
  fee: number
): number {
  const totalShares = heldShares + newShares
  if (totalShares === 0) return 0
  const totalCost = (heldNav * heldShares) + (newNav * newShares) + fee
  return totalCost / totalShares
}

/**
 * Calculate monthly investment amount for a goal
 * monthlyAmount = targetAmount / periodMonths
 */
export function calculateMonthlyAmount(targetAmount: number, periodMonths: number): number {
  if (periodMonths === 0) return 0
  return targetAmount / periodMonths
}
