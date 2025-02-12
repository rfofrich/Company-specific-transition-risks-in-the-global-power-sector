%Asset value
%
%Created Aug 14 2024
%by Robert Fofrich Navarro
%
%Calculates corporate asset value and assigns values to power plant parent company
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FUEL = 1;% sets fuel %1 COAL,2 GAS, 3 OIL, 4 Combined
clearvars -except ii; close all

TJ_to_BTu = 1/(9.478*1e8);
Kg_CO2_to_t_C02 = 1/1000;
BTu_perKWh_to_BTu_perMWh = 1000;

max_marker_size = 3000;
min_marker_size = 200; 


PowerPlantFuel = ["Coal", "Gas", "Oil"];
saveyear = 0;%saves decommission year; any other number loads decommission year
saveresults = 1;
randomsave = 1;%set to 1 to save MC randomization; zero value  loads MC randomization - section 11 only


if FUEL <4
CombineFuelTypeResults = 0;
elseif FUEL >3
CombineFuelTypeResults = 1;
end

current_year = 2024;
cutoffyear = 2035;%follows the index for carbontaxyear vector
CarbonPrice = 2000;%$/tCO2
CarbonTaxYear = current_year:2100;%sets the year for which the carbon tax is at its maximum

[ Dateindx] = find(CarbonTaxYear == cutoffyear);

StartYear = 1900;
EndYear = current_year;
Year = StartYear:EndYear;

RetailtoWholesaleConversionFactor = 1;%assumption

%Median PowerPlant Costs and Life from IPCC AR5 WGIII
%(https://www.ipcc.ch/site/assets/uploads/2018/02/ipcc_wg3_ar5_annex-iii.pdf)
%Power plant life

interest_rate_construction = .05; % interest rate over the construction loan (set as 5%)
DiscountRate = .1; %rate used by IEA 2020 report, 7% is in a highly regulated market, and 10% is in an environment with high risks

mean_Life_coal = 40;
Variable_OM_coal = 3.4;% $/MWh
Fixed_OM_coal = 23*1000;% $/MW
Construction_period_coal = 6; 
Capital_costs_coal = 2200*1000;% $/MW
Fuel_costs_coal = 4.1/3.6; % $/MWh
alpha_coal = DiscountRate/(1-(1+DiscountRate).^-mean_Life_coal);% percent
eta_coal = .39;% percent
Investment_costs_coal = (Capital_costs_coal/mean_Life_coal)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_coal)));

mean_Life_gas = 30;
Variable_OM_gas = 3.2;% $/MWh
Fixed_OM_gas = 7*1000;% $/MW
Construction_period_gas = 4; 
Capital_costs_gas = 1100*1000;% $/MW
Fuel_costs_gas = 8.9*3.6; % $/MWh
alpha_gas = DiscountRate/(1-(1+DiscountRate).^-mean_Life_gas);% percent
eta_gas = .55;% percent
Investment_costs_gas = (Capital_costs_gas/mean_Life_gas)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_gas)));

%Power plant ranges
LifeTimeRange = 20:5:60; 
CapacityFactorRange = .25:.05:.75;
AnnualHours = 8760;

%plus/minus age
Age_span = 20;% Power plant age range

%plus/minus CF
CF_span = .25;% Power plant capacity factor range
if FUEL == 1
years = 2021:(current_year + mean_Life_coal);
elseif FUEL == 2
years = 2021:(current_year + mean_Life_gas);
end

for gentype = FUEL
    if gentype == 1

        %vary profits and costs....
        %plot profits(y-axis) and costs(x-axis), stranded
        %assets(z-axis)
        load('../Data/Results/Coal_Plants');
        load('../Data/Results/Coal_Plants_strings');
        load('../Data/Results/CoalCostbyCountry')
        load('../Data/WholeSaleCostofElectricityCoal');
        CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx','standard');
        CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx','standard');
        load '../Data/Results/CoalColors'
        load('../Data/Results/DecommissionYearCoal')
        load('../Data/Results/OM_Costs_Coal.mat');
        load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
        
        matrixsize = 61;

        if randomsave == 1
            MC_values_1 = randi(matrixsize,10000,1);
            MC_values_2 = randi(matrixsize,10000,1);
            MC_values_3 = randi(matrixsize,10000,1);
            save("MC_values.mat","MC_values_1","MC_values_2","MC_values_3")
        elseif randomsave == 0 
            load("MC_values.mat");
        end
           

        FuelCosts = F_Costs;
        LifeLeft = mean_Life_coal - Plants(:,2);        
        sensitivity_range_fuel_costs = min(F_Costs(:)):(max(F_Costs(:))-min(F_Costs(:)))/(matrixsize-1):max(F_Costs(:));
        sensitivity_range_capital_costs = min(Plants(:,6)):(max(Plants(:,6))-min(Plants(:,6)))/(matrixsize-1):max(Plants(:,6));
        sensitivity_range_CT = 1:(500-1)/(matrixsize-1):500;%$dollars
        sensitivity_range_WS = 0:(200-0)/(matrixsize-1):200;%min to max with 100 steps $dollars/kwh
        CF_range = .2:(.9-.2)/(matrixsize-1):.9;
        PowerPlantCosts_CT = zeros(length(Plants),length(sensitivity_range_fuel_costs),length(sensitivity_range_capital_costs),length(sensitivity_range_CT));

        Plants(isnan(Plants))=0;
        max_Life = nanmax(LifeLeft);

        Stranded_Assets_based_on_added_costs = zeros(length(Plants),max_Life,length(CF_range),length(sensitivity_range_CT));
        for generator = 1:length(Plants)%%add in carbon tax portion
            for yr = 1:max_Life
                for CF = 1:length(CF_range)
                    for tax = 1:length(sensitivity_range_CT)
                        Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = sensitivity_range_CT(tax)*(Plants(generator,1).*CF_range(CF).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                    end
                end
            end
        end

        for generator = 1:length(Plants)%%add in carbon tax portion
            for yr = 1:max_Life
                for CF = 1:length(CF_range)
                    for tax = 1:length(sensitivity_range_CT)
                        Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = Stranded_Assets_based_on_added_costs(generator,yr,CF,tax)./((1 + DiscountRate).^yr);
                    end
                end
            end
        end
        
        [CarbonTax, Capacity_Factor] = meshgrid(sensitivity_range_CT, CF_range);
        vals = squeeze(nansum(nansum(Stranded_Assets_based_on_added_costs,1),2))/1e12; % converts to trillions of dollars
        
        contourrange = 0:.05:1000;
        
        figure()
        CF = contourf(Capacity_Factor, CarbonTax, vals, contourrange);
        % clabel(CF); % Add contour labels
        xlabel('Capacity Factor');
        ylabel('Carbon Tax');
        colormap(flip(brewermap(length(contourrange),'Spectral'))); % Ensure correct colormap usage
        c = colorbar;
        clim([0 80])
        c.Label.String = 'Stranded Assets (Trillions of Dollars)'; % Label the colorbar

        hold on;
        whiteContours = contour(Capacity_Factor, CarbonTax, vals, [5, 10,20, 30, 50, 70], 'LineColor', 'white', 'LineWidth', 1.5); % Example levels
        clabel(whiteContours);

        ax = gca;
        exportgraphics(ax,['../Plots/coal_sensitivity_plot.eps'],'ContentType','vector');

    elseif gentype == 2 
        
        load('../Data/Results/Gas_Plants');
        load('../Data/Results/Gas_Plants_strings');
        load('../Data/Results/GasCostbyCountry')
        load('../Data/WholeSaleCostofElectricityGas');
        CarbonTax19 = xlsread('../Data/CarbonTax1_9.xlsx');
        CarbonTax26 = xlsread('../Data/CarbonTax2_6.xlsx');
        load '../Data/Results/GasColors'
        load('../Data/Results/DecommissionYearGas')
        load('../Data/Results/OM_Costs_Gas.mat');
        
        matrixsize = 31;

        if randomsave == 1
            MC_values_1 = randi(matrixsize,10000,1);
            MC_values_2 = randi(matrixsize,10000,1);
            MC_values_3 = randi(matrixsize,10000,1);
            save("MC_values_Gas.mat","MC_values_1","MC_values_2","MC_values_3")
        elseif randomsave == 0 
            load("MC_values_Gas.mat");
        end
         
        FuelCosts = F_Costs;
        LifeLeft = mean_Life_gas - Plants(:,2);

        sensitivity_range_fuel_costs = min(F_Costs(:)):(max(F_Costs(:))-min(F_Costs(:)))/(matrixsize-1):max(F_Costs(:));
        sensitivity_range_capital_costs = min(Plants(:,6)):(max(Plants(:,6))-min(Plants(:,6)))/(matrixsize-1):max(Plants(:,6));
        sensitivity_range_CT = 1:(500-1)/(matrixsize-1):500;%$dollars
        sensitivity_range_WS = 0:(200-0)/(matrixsize-1):200;%min to max with 100 steps $dollars/kwh
        CF_range = .2:(.9-.2)/(matrixsize-1):.9;
        
        PowerPlantCosts_CT = zeros(length(Plants),length(sensitivity_range_fuel_costs),length(sensitivity_range_capital_costs),length(sensitivity_range_CT));

        Plants(isnan(Plants))=0;

        max_Life = nanmax(LifeLeft);

        Stranded_Assets_based_on_added_costs = zeros(length(Plants),max_Life,length(CF_range),length(sensitivity_range_CT));
        for generator = 1:length(Plants)%%add in carbon tax portion
            for yr = 1:max_Life
                for CF = 1:length(CF_range)
                    for tax = 1:length(sensitivity_range_CT)
                        Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = sensitivity_range_CT(tax)*Plants(generator,1).*CF_range(CF).*AnnualHours.*(Emission_factor(generator))* (Plants(generator,5)/100); 
                    end
                end
            end
        end

        for generator = 1:length(Plants)%%add in carbon tax portion
            for yr = 1:max_Life
                for CF = 1:length(CF_range)
                    for tax = 1:length(sensitivity_range_CT)
                        Stranded_Assets_based_on_added_costs(generator,yr,CF,tax) = Stranded_Assets_based_on_added_costs(generator,yr,CF,tax)./((1 + DiscountRate).^yr);
                    end
                end
            end
        end


        % StrandedAssets = zeros(matrixsize,matrixsize);%profits and costs
        % 
        % StrandedAssets(:,1) = PowerSectorStrandedAssets(:,1);
        % 
        % for i = 1:matrixsize
        %     for MC = 1:MC_values_1
        %         StrandedAssets(:,i) = (StrandedAssets(:,i) + PowerSectorStrandedAssets(:,MC_values_1(MC),MC_values_2(MC),MC_values_3(MC)))/2;%takes the mean of a monte carlo
        %     end
        % end
        
        [CarbonTax, Capacity_Factor] = meshgrid(sensitivity_range_CT, CF_range);
        vals = squeeze(nansum(nansum(Stranded_Assets_based_on_added_costs,1),2))/1e12; % converts to trillions of dollars
        
        contourrange = 0:.05:1000;
        
        figure()
        CF = contourf(Capacity_Factor, CarbonTax, vals, contourrange);
        % clabel(CF); % Add contour labels
        xlabel('Capacity Factor');
        ylabel('Carbon Tax');
        colormap(flip(brewermap(length(contourrange),'Spectral'))); % Ensure correct colormap usage
        c = colorbar;
        clim([0 80])
        c.Label.String = 'Stranded Assets (Trillions of Dollars)'; % Label the colorbar
        hold on;
        whiteContours = contour(Capacity_Factor, CarbonTax, vals, [3, 7, 11, 17, 24, 36, 50, 67, 87], 'LineColor', 'white', 'LineWidth', 1.5); % Example levels
        clabel(whiteContours);

        ax = gca;
        exportgraphics(ax,['../Plots/gas_sensitivity_plot.eps'],'ContentType','vector');
       
    end
end
