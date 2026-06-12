using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;
using UnityEngine.UI;

public enum PropertyType {
    ATM,
    MoneyTree,
    NFTs,
    TaxIncrementFinancing,
    Smuggling,
    MoneyLaundering,
    DayTrading,
    FlippingHouses,
    MultiLevelMarketing,
    HedgeFund,
    LegislativeAssets,
    ExecutiveAssets
}

public class Property : MonoBehaviour
{
    [SerializeField] PropertyTypeConfigSO propertyTypeConfigSO;
    [SerializeField] private int unitsOwned = 1;
    [SerializeField] TextMeshProUGUI purchaseButtonDisplay;
    [SerializeField] TextMeshProUGUI incomeButton;
    [SerializeField] TextMeshProUGUI unitsOwnedDisplay;
    [SerializeField] TextMeshProUGUI unlockButtonDisplay;
    [SerializeField] Image purchaseButtonImage;
    [SerializeField] Button purchaseButton;
    [SerializeField] GameObject unlockButton;
    [SerializeField] GameObject actionPanel;
    [SerializeField] IncomeCycle incomeCycle;
    [SerializeField] private Slider unitsSlider;
    [SerializeField] private Color purchaseButtonEnabledColor;
    [SerializeField] private Color purchaseButtonDisabledColor;
 
    private float unitCost = 0f;
    private Income income;
    private float incomePerUnitPerCycle = 5f;
    private int nextUpgradeTier = 20;
    private int purchaseMultiplier = 1;
    private float startingUnitCost;
    private float unitCostIncrease;
    private float startingIncomePerUnitPerCycle;
    private float incomeCycleLength;

    void Start()
    {
        InitializeConfigValues();

        income = GameObject.FindObjectOfType<Income>();

        if (unitsOwned > 0) {
            UnlockProperty();
        }
        else {
            LockProperty();
        }

        EventManager.onPurchaseMultiplierChanged += SetPurchaseMultiplier;
        EventManager.onBalanceChanged += OnBalanceChanged;
    }

    private void OnBalanceChanged(float balance) {
        SetPurchaseAffordability(balance);
        SetUnlockAffordability(balance);
        if (purchaseMultiplier == 0) {
            SetPurchaseButtonText();
        }
    }

    private void SetUnlockAffordability(float balance) {
        if (unlockButton.activeInHierarchy && balance >= unitCost) {
            unlockButton.GetComponent<Image>().color = Color.white;
            unlockButton.GetComponent<Button>().interactable = true;
        }
        else {
            unlockButton.GetComponent<Image>().color = Color.gray;
            unlockButton.GetComponent<Button>().interactable = false;
        }
    }

    private void SetPurchaseMultiplier(int multiplier) {
        purchaseMultiplier = multiplier;
        SetPurchaseButtonText();
        SetPurchaseAffordability(income.GetBalance());
    }

    private void SetPurchaseAffordability(float balance) {
        if (purchaseMultiplier == 0 && balance >= GetNextUnitCost(1)) {
            EnablePurchaseButton();
        }
        else if (purchaseMultiplier > 0 && balance >= GetPurchaseCost()) {
            EnablePurchaseButton();
        }
        else {
            DisablePurchaseButton();
        }
    }

    private void EnablePurchaseButton() {
        purchaseButtonImage.color = purchaseButtonEnabledColor;
        purchaseButton.interactable = true;
    }

    private void DisablePurchaseButton() {
        purchaseButtonImage.color = purchaseButtonDisabledColor;
        purchaseButton.interactable = false;
    }

    private float GetPurchaseCost() {
        if (purchaseMultiplier > 0) {
            // Need to loop through count of multiplier
            return GetNextUnitCost(purchaseMultiplier) * purchaseMultiplier;
        }
        else {
            int unitsToPurchase = GetPurchaseUnitCount();
            if (unitsToPurchase == 0) { unitsToPurchase = 1; }
            return GetNextUnitCost(unitsToPurchase);
        }
    }

    private int GetPurchaseUnitCount() {
        if (purchaseMultiplier > 0) {
            return purchaseMultiplier;
        }
        else {
            int i = 1;
            int unitsAffordable = 0;
            float balance = income.GetBalance();

            while (1==1) {
                if (GetNextUnitCost(i) <= balance) {
                    unitsAffordable = i;
                }
                else {
                    break;
                }
                i++;
            }
            return unitsAffordable;
        }
    }

    private void LockProperty() {
        unlockButton.SetActive(true);
        actionPanel.SetActive(false);
        SetUnlockButtonDisplay();
    }

    private void UnlockProperty() {
        unlockButton.SetActive(false);
        actionPanel.SetActive(true);

        unitsSlider.minValue = 0;
        unitsSlider.maxValue = nextUpgradeTier;
        unitsSlider.value = unitsOwned;
        incomeCycle.SetCycleLength(incomeCycleLength);
        incomeCycle.SetCycleIncome(incomePerUnitPerCycle);

        SetPurchaseButtonText();
        SetUnitsOwnedDisplay();
        SetPurchaseAffordability(income.GetBalance());
    }

    public void OnUnlockButtonClick() {
        if (income.GetBalance() >= unitCost) {
            unitsOwned++;
            UnlockProperty();
        }
    }

    private void SetUnlockButtonDisplay() {
        unlockButtonDisplay.text = propertyTypeConfigSO.GetPropertyTypeName() + " - Unlock for\n" + unitCost.ToString("$#,0");
    }

    private void InitializeConfigValues() {
        unitCost = propertyTypeConfigSO.GetStartingUnitCost();
        incomePerUnitPerCycle = propertyTypeConfigSO.GetStartingIncomePerUnitPerCycle();
        unitCost = propertyTypeConfigSO.GetStartingUnitCost();
        unitCostIncrease = propertyTypeConfigSO.GetUnitCostIncrease();
        incomePerUnitPerCycle = propertyTypeConfigSO.GetStartingIncomePerUnitPerCycle();
        incomeCycleLength = propertyTypeConfigSO.GetIncomeCycleLength();
    }

    private void SetPurchaseButtonText() {
        purchaseButtonDisplay.text = "Buy (" 
            + GetPurchaseUnitCount().ToString()
            +")\n" + GetPurchaseCost().ToString("$#,0");
    }

    public void ClickIncome() {
        if (unitsOwned > 0) {
            incomeCycle.SetIsActive(true);
        }
    }

    public void ClickPurchase() {
        float purchaseCost = GetPurchaseCost();
        if (purchaseCost <= income.GetBalance()) {
            unitsOwned += GetPurchaseUnitCount();
            income.Spend(purchaseCost);
            unitsSlider.value = unitsOwned;
            CalculateUpgradeModifier();
            float cycleIncome = Mathf.Floor(unitsOwned * incomePerUnitPerCycle);
            incomeCycle.SetCycleIncome(cycleIncome);
            SetPurchaseButtonText();
            SetUnitsOwnedDisplay();
        }
    }

    private void SetUnitsOwnedDisplay() {
        unitsOwnedDisplay.text = unitsOwned.ToString();
    }

    private void CalculateUpgradeModifier() {
        float priorUpgradeTier = unitsSlider.minValue;

        while (unitsOwned >= nextUpgradeTier) {
            priorUpgradeTier = nextUpgradeTier;
            incomePerUnitPerCycle *= 2;
            nextUpgradeTier *= 2;
        }
        unitsSlider.minValue = priorUpgradeTier;
        unitsSlider.maxValue = nextUpgradeTier;
    }

    private float GetNextUnitCost(int unitCount) {
        // return cost of next "unitCount" units
        float cost = 0;
        for (int i=1; i<=unitCount; i++) {
            cost += Mathf.Floor(unitCost * Mathf.Pow(unitCostIncrease, (unitsOwned+i)));
        }
        return cost;
    }
}
