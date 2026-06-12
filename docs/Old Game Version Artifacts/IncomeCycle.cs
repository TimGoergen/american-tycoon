using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class IncomeCycle : MonoBehaviour
{
    [SerializeField] private TextMeshProUGUI incomePerCycleDisplay;
    private Slider slider;
    private float cycleIncome = 0;
    private bool isActive = false;

    private void OnEnable() {
        slider = GetComponent<Slider>();
        incomePerCycleDisplay.text = cycleIncome.ToString();
        slider.value = 0;
    }

    public void SetCycleLength(float cycleLength) {
        slider.maxValue = cycleLength;
    }

    public void SetCycleIncome(float income) {
        cycleIncome = income;
        incomePerCycleDisplay.text = cycleIncome.ToString("#,0");
    }

    public void SetIsActive(bool newActiveStatus) {
        isActive = newActiveStatus;
    }

    void Update() {
        if (isActive) {
            MoveCycleSlider();
        }
    }

    private void MoveCycleSlider() {
        float sliderValue = slider.value;
        sliderValue += Time.deltaTime;
        if (sliderValue >= slider.maxValue)
        {
            EventManager.RaiseOnIncomeCollected(cycleIncome);
            sliderValue = 0;
            isActive = false;
        }

        slider.value = sliderValue;
    }
}
